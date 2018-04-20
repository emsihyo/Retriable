//
//  RetriableOperation.h
//  Retriable
//
//  Created by emsihyo on 2018/4/19.
//  Copyright © 2018年 emsihyo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RetriableOperation : NSOperation

@property (readonly) id        context;
@property (readonly) id        response;
@property (readonly) NSInteger currentRetryTime;
@property (readonly) NSError   *latestError;

/**
 init a operation.

 @param context optional, context used in the following blocks. default nil.
 @param completion optional, completion block executed when the operation did completed. default nil.
 @param retryAfter optional, a block to return the interval for next retry, if 0 returned, do not retry. default nil.
 @param start required, a block to start task.
 @param cancel required, a block to cancel task.
 @param cancelledErrorTemplates optional, error teimplates of canncelled error. default @[[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]].
 @return operation
 */
- (instancetype)initWithContext:(id)context completion:(void(^)(id context,id response,NSError *latestError))completion retryAfter:(NSTimeInterval(^)(id context,NSInteger currentRetryTime,NSError *latestError))retryAfter start:(void(^)(id context,void(^callback)(id response,NSError *error)))start cancel:(void(^)(id context))cancel cancelledErrorTemplates:(NSArray<NSError*>*)cancelledErrorTemplates;

/**
 pause operation.
 */
- (void)pause;

/**
 resume operation;
 */
- (void)resume;

@end








