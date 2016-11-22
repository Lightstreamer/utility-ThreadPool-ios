//
//  LSURLDispatcher.m
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

#import "LSURLDispatcher.h"
#import "LSURLDispatchOperation.h"
#import "LSURLDispatchOperation+Internals.h"
#import "LSURLAuthenticationChallengeSender.h"
#import "LSThreadPool.h"
#import "LSInvocation.h"
#import "LSTimerThread.h"
#import "LSLog.h"
#import "LSLog+Internals.h"

#define MAX_THREAD_IDLENESS                                (10.0)
#define THREAD_COLLECTOR_DELAY                             (15.0)

#define LS_TOO_MANY_LONG_RUNNING_REQUESTS                   (@"LSTooManyLongRunningRequests")


#pragma mark -
#pragma mark LSURLDispatcher extension

@interface LSURLDispatcher () {
	NSMutableDictionary *_decouplingThreadPoolsByEndPoint;

	NSMutableDictionary *_connectionCountsByEndPoint;
	NSMutableDictionary *_longRequestCountsByEndPoint;
    
    NSUInteger _maxRequestsPerEndPoint;
    NSUInteger _maxLongRunningRequestsPerEndPoint;
    
	NSCondition *_waitForFreeConnection;
    
    NSURLSession *_session;
    NSMutableDictionary *_operationsByTask;
}


#pragma mark -
#pragma mark Internal methods

- (NSUInteger) countOfRunningLongRequestsToEndPoint:(NSString *)endPoint;

- (NSString *) endPointForURL:(NSURL *)url;
- (NSString *) endPointForRequest:(NSURLRequest *)request;
- (NSString *) endPointForHost:(NSString *)host port:(int)port;


@end


#pragma mark -
#pragma mark LSURLDispatcher statics

static LSURLDispatcher *__sharedDispatcher= nil;


#pragma mark -
#pragma mark LSURLDispatcher implementation

@implementation LSURLDispatcher


#pragma mark -
#pragma mark Singleton management

+ (LSURLDispatcher *) sharedDispatcher {
	if (__sharedDispatcher)
		return __sharedDispatcher;
	
	@synchronized ([LSURLDispatcher class]) {
		if (!__sharedDispatcher)
			__sharedDispatcher= [[LSURLDispatcher alloc] init];
	}
	
	return __sharedDispatcher;
}

+ (void) dispose {
	if (!__sharedDispatcher)
		return;
	
	@synchronized ([LSURLDispatcher class]) {
        if (__sharedDispatcher) {
            [__sharedDispatcher dispose];
			__sharedDispatcher= nil;
        }
	}
}


#pragma mark -
#pragma mark Initialization

- (instancetype) init {
    NSURLSessionConfiguration *config= [NSURLSessionConfiguration defaultSessionConfiguration];
    
    return [self initWithMaxRequestsPerEndPoint:config.HTTPMaximumConnectionsPerHost
              maxLongRunningRequestsPerEndPoint:config.HTTPMaximumConnectionsPerHost / 2];
}

- (instancetype) initWithMaxRequestsPerEndPoint:(NSUInteger)maxRequestsPerEndPoint
                      maxLongRunningRequestsPerEndPoint:(NSUInteger)maxLongRunningRequestsPerEndPoint {
	if ((self = [super init])) {
        
        // Check parameters
        if (maxLongRunningRequestsPerEndPoint > maxRequestsPerEndPoint)
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"Parameter maxLongRunningRequestsPerEndPoint must be lower than or equal to maxRequestsPerEndPoint"
                                         userInfo:nil];
		
		// Initialization
		_decouplingThreadPoolsByEndPoint= [[NSMutableDictionary alloc] init];
		
		_connectionCountsByEndPoint= [[NSMutableDictionary alloc] init];
		_longRequestCountsByEndPoint= [[NSMutableDictionary alloc] init];
        
        _maxRequestsPerEndPoint= maxRequestsPerEndPoint;
        _maxLongRunningRequestsPerEndPoint= maxLongRunningRequestsPerEndPoint;
        
		_waitForFreeConnection= [[NSCondition alloc] init];
        
        // Initialize the session
        NSURLSessionConfiguration *config= [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPMaximumConnectionsPerHost= _maxRequestsPerEndPoint;
        
        _session= [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        
        // Initialize the operation-task map
        _operationsByTask= [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


#pragma mark -
#pragma mark Finalization

- (void) dispose {
    [_session invalidateAndCancel];
}


#pragma mark -
#pragma mark URL request dispatching and checking

- (NSData *) dispatchSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse * __autoreleasing *)response error:(NSError * __autoreleasing *)error delegate:(id <LSURLDispatchDelegate>)delegate {
	if (!request)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Request can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForRequest:request];
    
    // Wait for a free connection
    [self waitForFreeConnectionForEndPoint:endPoint];
    
    LSURLDispatchOperation *dispatchOp= [[LSURLDispatchOperation alloc] initWithDispatcher:self session:_session request:request endPoint:endPoint delegate:delegate gatherData:YES isLong:NO];

	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"starting synchronous operation %p for end-point %@", dispatchOp, endPoint];

	// Start the operation
	[dispatchOp startAndWaitForCompletion];

	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"synchronous operation %p for end-point %@ finished", dispatchOp, endPoint];

	if (response)
		*response= [dispatchOp.response copy];
	
	if (error)
		*error= [dispatchOp.error copy];
    
	return dispatchOp.data;
}

- (LSURLDispatchOperation *) dispatchShortRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate {
	if ((!request) || (!delegate))
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Request and/or delegate can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForRequest:request];
	
	LSURLDispatchOperation *dispatchOp= [[LSURLDispatchOperation alloc] initWithDispatcher:self session:_session request:request endPoint:endPoint delegate:delegate gatherData:NO isLong:NO];
	
	// Get the decoupling thread pool for this end-point
	LSThreadPool *pool= nil;
	@synchronized (_decouplingThreadPoolsByEndPoint) {
		pool= [_decouplingThreadPoolsByEndPoint objectForKey:endPoint];
		if (!pool) {
			NSString *poolName= [NSString stringWithFormat:@"LSURLDispatcher Decoupling %@", endPoint];
			pool= [[LSThreadPool alloc] initWithName:poolName size:1];
			
			[_decouplingThreadPoolsByEndPoint setObject:pool forKey:endPoint];
		}
	}
	
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"scheduling short operation: %p for end-point: %@", dispatchOp, endPoint];
	
	// Schedule the operation with the single-thread pool
	[pool scheduleInvocationForBlock:^() {
        
        // Wait for a free connection
        [self waitForFreeConnectionForEndPoint:endPoint];

        [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"starting short operation: %p for end-point: %@", dispatchOp, endPoint];
		
		[dispatchOp start];
	}];
	
	return dispatchOp;
}

- (LSURLDispatchOperation *) dispatchLongRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate {
	return [self dispatchLongRequest:request delegate:delegate policy:LSLongRequestLimitExceededPolicyThrow];
}

- (LSURLDispatchOperation *) dispatchLongRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate policy:(LSLongRequestLimitExceededPolicy)policy {
	if ((!request) || (!delegate))
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Request and/or delegate can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForRequest:request];
    LSURLDispatchOperation *dispatchOp= [[LSURLDispatchOperation alloc] initWithDispatcher:self session:_session request:request endPoint:endPoint delegate:delegate gatherData:NO isLong:YES];

	// Check if there's room for another long running request
	NSUInteger count= 0;
	@synchronized (_longRequestCountsByEndPoint) {
		count= [[_longRequestCountsByEndPoint objectForKey:endPoint] unsignedIntegerValue];
        
        if (count >= _maxLongRunningRequestsPerEndPoint) {
            switch (policy) {
                case LSLongRequestLimitExceededPolicyThrow:
                    
                    // Throw exception
                    @throw [NSException exceptionWithName:LS_TOO_MANY_LONG_RUNNING_REQUESTS
                                                   reason:@"Maximum number of concurrent long requests reached for end-point"
                                                 userInfo:@{@"endPoint": endPoint,
                                                            @"count": [NSNumber numberWithUnsignedInteger:count]}];
                    
                case LSLongRequestLimitExceededPolicyFail:
                    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"failing long operation: %p for end-point: %@", dispatchOp, endPoint];
                    
                    // Fail and return the request
                    [dispatchOp fail];
                    return dispatchOp;
                    
                case LSLongRequestLimitExceededPolicyEnqueue:
                    
                    // Enqueue the request as nothing was wrong
                    break;
                    
                default:
                    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                                   reason:@"Invalid policy"
                                                 userInfo:nil];
            }
        }

		// Update long running request count
		count++;

		[_longRequestCountsByEndPoint setObject:[NSNumber numberWithUnsignedInteger:count] forKey:endPoint];
	}
	
	// Get the decoupling thread pool for this end-point
	LSThreadPool *pool= nil;
	@synchronized (_decouplingThreadPoolsByEndPoint) {
		pool= [_decouplingThreadPoolsByEndPoint objectForKey:endPoint];
		if (!pool) {
			NSString *poolName= [NSString stringWithFormat:@"LSURLDispatcher Decoupling %@", endPoint];
			pool= [[LSThreadPool alloc] initWithName:poolName size:1];
			
			[_decouplingThreadPoolsByEndPoint setObject:pool forKey:endPoint];
		}
	}
	
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"scheduling long operation: %p for end-point: %@", dispatchOp, endPoint];
	
	// Schedule the operation with the single-thread pool
	[pool scheduleInvocationForBlock:^() {
        
        // Wait for a free connection
        [self waitForFreeConnectionForEndPoint:endPoint];

        [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"starting long operation: %p for end-point: %@", dispatchOp, endPoint];
		
		[dispatchOp start];
		
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"long running request count: %lu", (unsigned long) count];
	}];

	return dispatchOp;
}

- (BOOL) isLongRequestAllowed:(NSURLRequest *)request {
	if (!request)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Request can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForRequest:request];
    
    NSUInteger count= [self countOfRunningLongRequestsToEndPoint:endPoint];
    return (count < _maxLongRunningRequestsPerEndPoint);
}

- (BOOL) isLongRequestAllowedToURL:(NSURL *)url {
	if (!url)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"URL can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForURL:url];
    
    NSUInteger count= [self countOfRunningLongRequestsToEndPoint:endPoint];
    return (count < _maxLongRunningRequestsPerEndPoint);
}

- (BOOL) isLongRequestAllowedToHost:(NSString *)host port:(int)port {
	if (!host)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Host can't be nil"
									 userInfo:nil];
	
	NSString *endPoint= [self endPointForHost:host port:port];

    NSUInteger count= [self countOfRunningLongRequestsToEndPoint:endPoint];
    return (count < _maxLongRunningRequestsPerEndPoint);
}

- (NSUInteger) countOfRunningLongRequestsToURL:(nonnull NSURL *)url {
    if (!url)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"URL can't be nil"
                                     userInfo:nil];
    
    NSString *endPoint= [self endPointForURL:url];
    return [self countOfRunningLongRequestsToEndPoint:endPoint];
}

- (NSUInteger) countOfRunningLongRequestsToHost:(nonnull NSString *)host port:(int)port {
    if (!host)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Host can't be nil"
                                     userInfo:nil];
    
    NSString *endPoint= [self endPointForHost:host port:port];
    
    return [self countOfRunningLongRequestsToEndPoint:endPoint];
}


#pragma mark -
#pragma mark Properties

@dynamic maxRequestsPerEndPoint;

- (NSUInteger) maxRequestsPerEndPoint {
    return _maxRequestsPerEndPoint;
}

@dynamic maxLongRunningRequestsPerEndPoint;

- (NSUInteger) maxLongRunningRequestsPerEndPoint {
    return _maxLongRunningRequestsPerEndPoint;
}

- (void) setMaxLongRunningRequestsPerEndPoint:(NSUInteger)maxLongRunningRequestsPerEndPoint {
    
    // Check parameter
    if (maxLongRunningRequestsPerEndPoint > _maxRequestsPerEndPoint)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Must be lower than or equal to maxRequestsPerEndPoint"
                                     userInfo:nil];
    
    _maxLongRunningRequestsPerEndPoint= maxLongRunningRequestsPerEndPoint;
}


#pragma mark -
#pragma mark Operation synchronization (for internal use only)

- (void) waitForFreeConnectionForEndPoint:(NSString *)endPoint {
    NSUInteger connectionCount= 0;
    
	do {
		@synchronized (_connectionCountsByEndPoint) {
			
			// Retrieve current connection count
            NSNumber *connectionCountNumber= [_connectionCountsByEndPoint objectForKey:endPoint];
            connectionCount= [connectionCountNumber unsignedIntegerValue];
				
            // Check if we have to wait
            if (connectionCount < _maxRequestsPerEndPoint) {
                connectionCount++;
                
                [_connectionCountsByEndPoint setObject:[NSNumber numberWithUnsignedInteger:connectionCount] forKey:endPoint];
                break;
            }
		}
		
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"waiting for a free connection for end-point: %@...", endPoint];

		// If we've got here, we have to wait for a free connection and retry
		[_waitForFreeConnection lock];
		[_waitForFreeConnection wait];
		[_waitForFreeConnection unlock];

	} while (YES);
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"obtained a free connection for end-point: %@, connection count is now: %lu (max %lu)", endPoint, (unsigned long) connectionCount, (unsigned long) _maxRequestsPerEndPoint];
}

- (void) connectionDidFreeForEndPoint:(NSString *)endPoint {
    NSUInteger connectionCount= 0;
    
	@synchronized (_connectionCountsByEndPoint) {
        
        // Retrieve current connection count
        NSNumber *connectionCountNumber= [_connectionCountsByEndPoint objectForKey:endPoint];
        connectionCount= [connectionCountNumber unsignedIntegerValue];
        
        connectionCount--;
        [_connectionCountsByEndPoint setObject:[NSNumber numberWithUnsignedInteger:connectionCount] forKey:endPoint];
    }
    
	// Signal there's a free connection
	[_waitForFreeConnection lock];
	[_waitForFreeConnection signal];
	[_waitForFreeConnection unlock];
    
    [LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"freed a connection for end-point: %@, connection count is now: %lu (max %lu)", endPoint, (unsigned long) connectionCount, (unsigned long) _maxRequestsPerEndPoint];
}


#pragma mark -
#pragma mark Operation notifications (for internal use only)

- (void) operation:(LSURLDispatchOperation *)dispatchOp didStartWithTask:(NSURLSessionDataTask *)task {
    
    // Store the operation-task association for use during the event dispatch
    @synchronized (_operationsByTask) {
        [_operationsByTask setObject:dispatchOp forKey:[NSNumber numberWithInteger:task.taskIdentifier]];
    }
}

- (void) operation:(LSURLDispatchOperation *)dispatchOp didFinishWithTask:(NSURLSessionDataTask *)task {
	if (dispatchOp.isLong) {
		
		// Update long running request count
		NSUInteger count= 0;
		@synchronized (_longRequestCountsByEndPoint) {
			count= [[_longRequestCountsByEndPoint objectForKey:dispatchOp.endPoint] unsignedIntegerValue];
			count--;
			
			[_longRequestCountsByEndPoint setObject:[NSNumber numberWithUnsignedInteger:count] forKey:dispatchOp.endPoint];
		}
		
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"long running request count: %lu", (unsigned long) count];
	}

    // Mark the connection as free
    [self connectionDidFreeForEndPoint:dispatchOp.endPoint];
    
    // Clear the operation-task association
    @synchronized (_operationsByTask) {
        [_operationsByTask removeObjectForKey:[NSNumber numberWithInteger:task.taskIdentifier]];
    }
}


#pragma mark -
#pragma mark methods of NSURLSessionTaskDelegate and NSURLSessionDataDelegate

- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler {
    
    // Retrieve corresponding dispatch operation
    LSURLDispatchOperation *dispatchOp= nil;
    @synchronized (_operationsByTask) {
        dispatchOp= [_operationsByTask objectForKey:[NSNumber numberWithInteger:task.taskIdentifier]];
        if (!dispatchOp) {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }
    }
    
    // Wrap the sender and call event on the operation
    LSURLAuthenticationChallengeSender *sender= [[LSURLAuthenticationChallengeSender alloc] init];
    NSURLAuthenticationChallenge *wrapperChallenge= [[NSURLAuthenticationChallenge alloc] initWithAuthenticationChallenge:challenge sender:sender];
    [dispatchOp taskWillSendRequestForAuthenticationChallenge:wrapperChallenge];
    
    // Continue the request processing
    completionHandler(sender.disposition, sender.credential);
}

- (void) URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didCompleteWithError:(nullable NSError *)error {
    
    // Retrieve corresponding dispatch operation
    LSURLDispatchOperation *dispatchOp= nil;
    @synchronized (_operationsByTask) {
        dispatchOp= [_operationsByTask objectForKey:[NSNumber numberWithInteger:task.taskIdentifier]];
        if (!dispatchOp)
            return;
    }
    
    // Call corresponding event on the operation
    if (error)
        [dispatchOp taskDidFailWithError:error];
    else
        [dispatchOp taskDidFinishLoading];
}

- (void) URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
    completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    // Retrieve corresponding dispatch operation
    LSURLDispatchOperation *dispatchOp= nil;
    @synchronized (_operationsByTask) {
        dispatchOp= [_operationsByTask objectForKey:[NSNumber numberWithInteger:dataTask.taskIdentifier]];
        if (!dispatchOp) {
            completionHandler(NSURLSessionResponseCancel);
            return;
        }
    }
    
    // Call event on the operation
    [dispatchOp taskDidReceiveResponse:response];

    // Continue the request processing
    completionHandler(NSURLSessionResponseAllow);
}

- (void) URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    
    // Retrieve corresponding dispatch operation
    LSURLDispatchOperation *dispatchOp= nil;
    @synchronized (_operationsByTask) {
        dispatchOp= [_operationsByTask objectForKey:[NSNumber numberWithInteger:dataTask.taskIdentifier]];
        if (!dispatchOp)
            return;
    }
    
    // Call event on the operation
    [dispatchOp taskDidReceiveData:data];
}


#pragma mark -
#pragma mark Internal methods

- (NSUInteger) countOfRunningLongRequestsToEndPoint:(NSString *)endPoint {
    NSUInteger count= 0;
    
    @synchronized (_longRequestCountsByEndPoint) {
        count= [[_longRequestCountsByEndPoint objectForKey:endPoint] unsignedIntegerValue];
    }
    
    return count;
}

- (NSString *) endPointForURL:(NSURL *)url {
	int port= [url.port intValue];
	if (!port)
		port= ([url.scheme isEqualToString:@"https"] ? 443 : 80);
    
    return [self endPointForHost:url.host port:port];
}

- (NSString *) endPointForRequest:(NSURLRequest *)request {
    return [self endPointForURL:request.URL];
}

- (NSString *) endPointForHost:(NSString *)host port:(int)port {
	NSString *endPoint= [NSString stringWithFormat:@"%@:%d", host, port];
	
	return endPoint;
}


@end
