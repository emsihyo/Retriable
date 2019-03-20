//
//  RetriableOperation.h
//  Retriable
//
//  Created by retriable on 2018/4/19.
//  Copyright © 2018年 retriable. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RetriableOperation : NSOperation
/**
 init a operation.

 @param completion optional, completion block executed when the operation did completed. default nil.
 @param retryAfter optional, a block to return the interval for next retry, if 0 returned, do not retry. default nil.
 @param start required, a block to start task.
 @param cancel required, a block to cancel task.
 @param cancelledErrorTemplates optional, error teimplates of canncelled error. default @[[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]].
 @return operation
 */
- (instancetype _Nullable)initWithCompletion:(void(^ _Nullable)(id _Nullable response,NSError * _Nullable latestError))completion
                     retryAfter:(NSTimeInterval(^ _Nullable)(NSInteger currentRetryTime,NSError * _Nullable latestError))retryAfter
                          start:(void(^_Nonnull)(void(^ _Nonnull callback)(id _Nullable response,NSError * _Nullable error)))start
                         cancel:(void(^_Nonnull)(void))cancel
        cancelledErrorTemplates:(NSArray<NSError*>* _Nullable)cancelledErrorTemplates;

/**
 pause operation.
 */
- (void)pause;

/**
 resume operation;
 */
- (void)resume;

/**
 enable log or not.

 @param enabled enabled
 */

+ (void)setLogEnabled:(BOOL)enabled;

@end








