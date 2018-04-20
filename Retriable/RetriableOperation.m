//
//  RetriableOperation.m
//  Retriable
//
//  Created by emsihyo on 2018/4/19.
//  Copyright © 2018年 emsihyo. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "RetriableOperation.h"
#if TARGET_OS_IPHONE
#if TARGET_OS_WATCH
#else
#define RETRIABLE_TARGET_OS_IPHONE 1
#endif
#endif

#if RETRIABLE_TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
//#define RetryLog(...) printf("\n%s\n",[[NSString stringWithFormat:__VA_ARGS__] UTF8String])
#define RetryLog(...)

@interface RetriableOperation ()

@property (nonatomic,assign) BOOL                       _isExecuting;
@property (nonatomic,assign) BOOL                       _isFinished;

@property (nonatomic,strong) void(^_completion)(id response,NSError *latestError);
@property (nonatomic,strong) NSTimeInterval (^retryAfter)(NSInteger currentRetryTime,NSError *latestError);
@property (nonatomic,strong) void(^_start)(void(^callback)(id response,NSError *error));
@property (nonatomic,strong) void(^_cancel)(void);
@property (nonatomic,strong) NSArray<NSError*> *cancelledErrorTemplates;

@property (nonatomic,assign) NSInteger                  currentRetryTime;
@property (nonatomic,strong) NSError                    *latestError;
@property (nonatomic,strong) id                         response;
@property (nonatomic,retain) dispatch_source_t          timer;
@property (nonatomic,strong) NSRecursiveLock            *lock;
#if RETRIABLE_TARGET_OS_IPHONE
@property (nonatomic,assign) UIBackgroundTaskIdentifier backgroundTaskId;
#endif
@property (nonatomic,assign) BOOL                       isPaused;

@end

@implementation RetriableOperation

- (void)dealloc{
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
    [self cancel];
    RetryLog(@"operation: %@\nwill dealloc",self.context);
}

- (instancetype)initWithCompletion:(void(^)(id response,NSError *latestError))completion
                        retryAfter:(NSTimeInterval(^)(NSInteger currentRetryTime,NSError *latestError))retryAfter
                             start:(void(^)(void(^callback)(id response,NSError *error)))start
                            cancel:(void(^)(void))cancel
           cancelledErrorTemplates:(NSArray<NSError*>*)cancelledErrorTemplates{
    self=[super init];
    if (!self) return self;
    self.lock=[[NSRecursiveLock alloc]init];
    self.retryAfter = retryAfter;
    self._completion =completion;
    self._start = start;
    self._cancel = cancel;
    if (cancelledErrorTemplates.count>0) self.cancelledErrorTemplates=cancelledErrorTemplates;
    else self.cancelledErrorTemplates=@[[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
#if RETRIABLE_TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
    return self;
}

- (void)start{
    [self.lock lock];
    [self start_];
    [self.lock unlock];
}

- (void)cancel{
    [self.lock lock];
    if (self.isCancelled||self.isFinished) {
        [self.lock unlock];
        return;
    }
    [super cancel];
    [self cancel_];
    self.latestError=self.cancelledErrorTemplates.firstObject;
    [self complete];
    [self.lock unlock];
}

- (void)pause{
    self.isPaused=YES;
}

- (void)resume{
    self.isPaused=NO;
}

- (void)start_{
    if (self.isCancelled||self.isFinished) return;
    [self beginBackgroundTask];
    if (self.isPaused) return;
    if (self.currentRetryTime==0) RetryLog(@"operation: %@\ndid start",self.context);
    else RetryLog(@"operation: %@\nretrying: %ld", self.context,(long)self.currentRetryTime);
    self._isExecuting=YES;
    __weak typeof(self) weakSelf=self;
    self._start(^(id response, NSError *error) {
        __strong typeof(weakSelf) self=weakSelf;
        [self.lock lock];
        if (self.isCancelled||self.isFinished){
            [self.lock unlock];
            return;
        }
        for (NSError * template in self.cancelledErrorTemplates){
            if ([error.domain isEqualToString:template.domain]&&error.code==template.code){
                [self.lock unlock];
                return;
            }
        }
        self.response=response;self.latestError=error;
        if (!error||!self.retryAfter) {
            [self complete];
            [self.lock unlock];
            return;
        }
        NSTimeInterval interval=self.retryAfter(++self.currentRetryTime,self.latestError);
        if (interval==0) {
            [self complete];
            [self.lock unlock];
            return;
        }
        if (self.isPaused){
            [self.lock unlock];
            return;
        }
        if (self.timer) {
            NSAssert(0, @"there is a issue about duplicated response");
            dispatch_source_cancel(self.timer);
            self.timer=nil;
        }
        RetryLog(@"operation: %@\nwill retry after: %.2f, error: %@",self.context,interval,self.latestError);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(self.timer, dispatch_walltime(DISPATCH_TIME_NOW, interval*NSEC_PER_SEC), INT32_MAX * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(self.timer, ^{
            __strong typeof(weakSelf) self=weakSelf;
            [self.lock lock];
            dispatch_source_cancel(self.timer);
            self.timer=nil;
            [self start_];
            [self.lock unlock];
        });
        dispatch_resume(self.timer);
        [self.lock unlock];
    });
}

- (void)cancel_{
    self._cancel();
    if (!self.timer) return;
    dispatch_source_cancel(self.timer);
    self.timer=nil;
}

- (void)complete{
    self._isExecuting=NO;
    self._isFinished=YES;
    if (self._completion) self._completion(self.response, self.latestError);
    RetryLog(@"operation: %@\ndid complete\nresponse:%@\nerror:%@",self.context,self.response,self.latestError);
    [self endBackgroundTask];
}

#pragma mark --
#pragma mark -- background task

#if RETRIABLE_TARGET_OS_IPHONE
- (void)applicationWillEnterForeground{
    [self.lock lock];
    if (self.isExecuting&&self.backgroundTaskId==UIBackgroundTaskInvalid) [self start_];
    [self.lock unlock];
}
#endif

- (void)beginBackgroundTask{
#if RETRIABLE_TARGET_OS_IPHONE
    if (self.backgroundTaskId!=UIBackgroundTaskInvalid) return;
    __weak typeof(self) weakSelf=self;
    self.backgroundTaskId=[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        __strong typeof(weakSelf) self=weakSelf;
        [self.lock lock];
        if (self.executing&&!self.isPaused) [self cancel_];
        self.backgroundTaskId=UIBackgroundTaskInvalid;
        RetryLog(@"operation: %@\nbackground task did expired",self.context);
        [self.lock unlock];
    }];
    RetryLog(@"operation: %@\nbackground task did begin",self.context);
#endif
}

- (void)endBackgroundTask{
#if RETRIABLE_TARGET_OS_IPHONE
    if (self.backgroundTaskId==UIBackgroundTaskInvalid) return;
    [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskId];
    self.backgroundTaskId=UIBackgroundTaskInvalid;
    RetryLog(@"operation: %@\nbackground task did end",self.context);
#endif
}

- (void)setIsPaused:(BOOL)isPaused{
    [self.lock lock];
    if (_isPaused==isPaused) {
        [self.lock unlock];
        return;
    }
    _isPaused=isPaused;
#if RETRIABLE_TARGET_OS_IPHONE
    if (!self.executing||self.backgroundTaskId==UIBackgroundTaskInvalid){
#else
    if (!self.executing){
#endif
        [self.lock unlock];
        return;
    }
    if (isPaused) [self cancel_];
    else [self start_];
    [self.lock unlock];
}

- (void)set_isExecuting:(BOOL)_isExecuting{
    [self willChangeValueForKey:@"isExecuting"];
    __isExecuting=_isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)set_isFinished:(BOOL)_isFinished{
    [self willChangeValueForKey:@"isFinished"];
    __isFinished=_isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isExecuting{
    return __isExecuting;
}

- (BOOL)isFinished{
    return __isFinished;
}

- (BOOL)isAsynchronous{
    return YES;
}

@end
