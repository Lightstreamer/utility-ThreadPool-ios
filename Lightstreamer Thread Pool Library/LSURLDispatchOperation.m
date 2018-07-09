//
//  LSURLDispatchOperation.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright (c) Lightstreamer Srl
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LSURLDispatchOperation.h"
#import "LSURLDispatchOperation+Internals.h"
#import "LSURLDispatcher.h"
#import "LSURLDispatcher+Internals.h"
#import "LSLog.h"
#import "LSLog+Internals.h"

#define ERROR_DOMAIN                          (@"LSURLDispatcherDomain")

#define ERROR_CODE_NO_TASK                    (-1701)
#define ERROR_CODE_NO_SPARE_CONNECTION        (-1702)


#pragma mark -
#pragma mark LSURLDispatchOperation extension

@interface LSURLDispatchOperation () {
    LSURLDispatcher * __weak _dispatcher;
    
    NSURLRequest *_request;
    NSString *_endPoint;
    id <LSURLDispatchDelegate> _delegate;
    BOOL _gathedData;
    BOOL _isLong;
    
    NSCondition *_waitForCompletion;
    
    dispatch_queue_t _notificationQueue;

    dispatch_queue_t _timeoutQueue;
    dispatch_block_t _timeoutBlock;
    
    NSURLResponse *_response;
    NSError *_error;
    NSMutableData *_data;
    
    NSURLSession * __weak _session;
    NSURLSessionDataTask *_task;
}


#pragma mark -
#pragma mark Internal non-threaded operations

- (void) timeout;


@end


#pragma mark -
#pragma mark LSURLDispatchOperation implementation

@implementation LSURLDispatchOperation


#pragma mark -
#pragma mark Initialization

- (instancetype) initWithDispatcher:(LSURLDispatcher *)dispatcher session:(NSURLSession *)session request:(NSURLRequest *)request endPoint:(NSString *)endPoint delegate:(id <LSURLDispatchDelegate>)delegate gatherData:(BOOL)gatherData isLong:(BOOL)isLong {
    if ((self = [super init])) {
        
        // Initialization
        _dispatcher= dispatcher;
        
        _session= session;
        _request= request;
        _endPoint= endPoint;
        _delegate= delegate;
        _gathedData= gatherData;
        _isLong= isLong;
        
        _waitForCompletion= [[NSCondition alloc] init];
        
        NSString *queueName= [NSString stringWithFormat:@"LSURLDispatchOperation Notification Queue for %@", endPoint];
        _notificationQueue= dispatch_queue_create([queueName cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);
        
        queueName= [NSString stringWithFormat:@"LSURLDispatchOperation Timeout Queue for %@", endPoint];
        _timeoutQueue= dispatch_queue_create([queueName cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}


#pragma mark -
#pragma mark Execution

- (void) start {
    if (_gathedData)
        _data= [[NSMutableData alloc] init];
    
    // Prepare a copy of the request
    NSMutableURLRequest *request= [_request mutableCopy];
    
    // Check timeout
    NSTimeInterval timeout= _request.timeoutInterval;
    if (timeout > 0.0) {
        
        // Start the local timeout timer and clear the timeout for
        // the operating system (can't be trusted)
        __weak LSURLDispatchOperation *weakSelf= self;
        _timeoutBlock= dispatch_block_create(0, ^{
            [weakSelf timeout];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), _timeoutQueue, _timeoutBlock);

        request.timeoutInterval= 0.0;
    }

    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"starting task of operation %p for end-point: %@", self, _endPoint];
    
    // Create a new data task
    _task= [_session dataTaskWithRequest:request];
    if (!_task) {
        
        // No task created, compose the error
        NSError *error= [NSError errorWithDomain:ERROR_DOMAIN
                                            code:ERROR_CODE_NO_TASK
                                        userInfo:@{NSLocalizedDescriptionKey: @"Couldn't create a new task for requested URL",
                                                   NSURLErrorKey: request.URL}];
        
        // Store the error
        _error= error;
        
        [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"connection of operation %p for end-point: %@ failed due to nil task returned by session", self, _endPoint];
        
        // Cancel the timeout timer
        dispatch_block_cancel(_timeoutBlock);
        
        // Schedule call to delegate
        dispatch_async(_notificationQueue, ^{
            @try {
                [self->_delegate dispatchOperation:self didFailWithError:error];
                
            } @catch (NSException *e) {
                [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying error to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
            }
        });
        
    } else {
        
        // Notify the dispatcher
        [_dispatcher operation:self didStartWithTask:_task];
        
        // Resume the task
        [_task resume];
    }
}

- (void) startAndWaitForCompletion {
    
    // Acquire the completion lock
    [_waitForCompletion lock];

    // Start the connection
    [self start];
    
    if (_task) {
        
        // Wait for a signal
        [_waitForCompletion wait];
    }
    
    [_waitForCompletion unlock];
}

- (void) fail {
    
    // Compose the error
    NSError *error= [NSError errorWithDomain:ERROR_DOMAIN
                                        code:ERROR_CODE_NO_SPARE_CONNECTION
                                    userInfo:@{NSLocalizedDescriptionKey: @"No connection available",
                                               NSURLErrorKey: _request.URL}];
    
    // Store the error
    _error= error;
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"connection of operation %p for end-point: %@ failed due to no connection available", self, _endPoint];
    
    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperation:self didFailWithError:error];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying error to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
}

- (void) cancel {
    NSURLSessionDataTask *oldTask= nil;
    
    @synchronized (self) {
        
        // Avoid wasting time if the task has been cancelled or is already finished
        if (!_task)
            return;
        
        // Release the task strong reference
        oldTask= _task;
        _task= nil;
    }
    
    // Cancel connection
    [oldTask cancel];
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"task of operation %p for end-point: %@ cancelled", self, _endPoint];
    
    // Cancel the timeout timer
    dispatch_block_cancel(_timeoutBlock);

    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperationDidFinish:self];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying finish to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
    
    // Notify waiting threads
    [_waitForCompletion lock];
    [_waitForCompletion broadcast];
    [_waitForCompletion unlock];
    
    // Notify the dispatcher
    [_dispatcher operation:self didFinishWithTask:oldTask];
}

- (void) timeout {
    NSURLSessionDataTask *oldTask= nil;
    
    @synchronized (self) {
        
        // Avoid wasting time if the connection has been cancelled or is already finished
        if (!_task)
            return;
        
        // Release the task strong reference
        oldTask= _task;
        _task= nil;
    }
    
    // Cancel connection
    [oldTask cancel];
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"task of operation %p for end-point: %@ timed out", self, _endPoint];
    
    // Compose the error
    NSError *error= [[NSError alloc] initWithDomain:NSURLErrorDomain
                                               code:NSURLErrorTimedOut
                                           userInfo:@{NSURLErrorFailingURLStringErrorKey: _request.URL.description,
                                                      NSLocalizedDescriptionKey: @"The request timed out.",
                                                      NSUnderlyingErrorKey: [NSError errorWithDomain:ERROR_DOMAIN
                                                                                                code:NSURLErrorTimedOut
                                                                                            userInfo:nil]}];
    
    // Store the error
    _error= error;
    
    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperation:self didFailWithError:error];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying error to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
    
    // Notify waiting threads
    [_waitForCompletion lock];
    [_waitForCompletion broadcast];
    [_waitForCompletion unlock];
    
    // Notify the dispatcher
    [_dispatcher operation:self didFinishWithTask:oldTask];
}


#pragma mark -
#pragma mark Events for NSURLSessionDataTask (for internal use only)

- (void) taskWillSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    // Avoid wasting time if task has been cancelled
    @synchronized (self) {
        if (!_task)
            return;
    }
    
    if ([_delegate respondsToSelector:@selector(dispatchOperation:willSendRequestForAuthenticationChallenge:)]) {
        
        // Forward authentication call to delegate
        @try {
            [_delegate dispatchOperation:self willSendRequestForAuthenticationChallenge:challenge];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying challenge to delegate: %@, reason: '%@'\nCall stack:%@", self, _endPoint, e.name, e.reason, e.callStackSymbols];
        }
        
    } else
        [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
}

- (void) taskDidReceiveResponse:(NSURLResponse *)response {
    
    // Avoid wasting time if task has been cancelled
    @synchronized (self) {
        if (!_task)
            return;
    }
    
    _response= response;
    
    // Truncate current data buffer
    _data.length= 0;
    
    // Cancel the timeout timer at the response only for long operations,
    // other operations will cancel it at finish or failure
    if (_isLong)
        dispatch_block_cancel(_timeoutBlock);
    
    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperation:self didReceiveResponse:response];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying response to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
}

- (void) taskDidReceiveData:(NSData *)data {
    
    // Avoid wasting time if task has been cancelled
    @synchronized (self) {
        if (!_task)
            return;
    }
    
    [_data appendData:data];
    
    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperation:self didReceiveData:data];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying data to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
}

- (void) taskDidFailWithError:(NSError *)error {
    NSURLSessionDataTask *oldTask= nil;

    @synchronized (self) {
        
        // Avoid wasting time if task has been cancelled
        if (!_task)
            return;
        
        // Release the task strong reference
        oldTask= _task;
        _task= nil;
    }
    
    // Store the error
    _error= error;
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"connection of operation %p for end-point: %@ failed with error: %@", self, _endPoint, error];
    
    // Cancel the timeout timer
    dispatch_block_cancel(_timeoutBlock);
    
    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperation:self didFailWithError:error];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying error to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
    
    // Notify waiting threads
    [_waitForCompletion lock];
    [_waitForCompletion broadcast];
    [_waitForCompletion unlock];
    
    // Notify the dispatcher
    [_dispatcher operation:self didFinishWithTask:oldTask];
}

- (void) taskDidFinishLoading {
    NSURLSessionDataTask *oldTask= nil;

    @synchronized (self) {
        
        // Avoid wasting time if task has been cancelled
        if (!_task)
            return;
        
        // Release the task strong reference
        oldTask= _task;
        _task= nil;
    }
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"connection of operation %p for end-point: %@ finished loading", self, _endPoint];
    
    // Cancel the timeout timer
    dispatch_block_cancel(_timeoutBlock);

    // Schedule call to delegate
    dispatch_async(_notificationQueue, ^{
        @try {
            [self->_delegate dispatchOperationDidFinish:self];
            
        } @catch (NSException *e) {
            [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self->_dispatcher log:@"connection of operation %p for end-point: %@ caught exception while notifying finish to delegate: %@, reason: '%@'\nCall stack:%@", self, self->_endPoint, e.name, e.reason, e.callStackSymbols];
        }
    });
    
    // Notify waiting threads
    [_waitForCompletion lock];
    [_waitForCompletion broadcast];
    [_waitForCompletion unlock];
    
    // Notify the dispatcher
    [_dispatcher operation:self didFinishWithTask:oldTask];
}


#pragma mark -
#pragma mark Properties

@synthesize request= _request;
@synthesize endPoint= _endPoint;
@synthesize isLong= _isLong;

@synthesize response= _response;
@synthesize error= _error;
@synthesize data= _data;


@end
