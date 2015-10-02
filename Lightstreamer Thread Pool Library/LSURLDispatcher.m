//
//  LSURLDispatcher.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright 2013-2015 Weswit Srl
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
#import "LSURLDispatcherThread.h"
#import "LSThreadPool.h"
#import "LSInvocation.h"
#import "LSTimerThread.h"
#import "LSLog.h"
#import "LSLog+Internals.h"

#define MAX_THREADS_PER_ENDPOINT                            (4)
#define MAX_THREAD_IDLENESS                                (10.0)
#define THREAD_COLLECTOR_DELAY                             (15.0)

#define DEFAULT_MAX_LONG_RUNNING_REQUESTS_PER_ENDPOINT      (2)

#define LS_TOO_MANY_LONG_RUNNING_REQUESTS                   (@"LSTooManyLongRunningRequests")


#pragma mark -
#pragma mark LSURLDispatcher extension

@interface LSURLDispatcher () {
	NSMutableDictionary *_decouplingThreadPoolsByEndPoint;

	NSMutableDictionary *_freeThreadsByEndPoint;
	NSMutableDictionary *_busyThreadsByEndPoint;
	
	NSMutableDictionary *_longRequestCountsByEndPoint;
	
	NSCondition *_waitForFreeThread;
	int _nextThreadId;
}


#pragma mark -
#pragma mark Thread management

- (void) collectIdleThreads;
- (void) stopThreads;


#pragma mark -
#pragma mark Internal methods

- (BOOL) isLongRequestAllowedToEndPoint:(NSString *)endPoint;

- (NSString *) endPointForURL:(NSURL *)url;
- (NSString *) endPointForRequest:(NSURLRequest *)request;
- (NSString *) endPointForHost:(NSString *)host port:(int)port;


@end


#pragma mark -
#pragma mark LSURLDispatcher statics

static LSURLDispatcher *__sharedDispatcher = nil;
static NSUInteger __maxLongRunningRequestsPerEndPoint= DEFAULT_MAX_LONG_RUNNING_REQUESTS_PER_ENDPOINT;


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
			[__sharedDispatcher stopThreads];
		}
	}
}


#pragma mark -
#pragma mark Class properties

+ (NSUInteger) maxLongRunningRequestsPerEndPoint {
	return __maxLongRunningRequestsPerEndPoint;
}

+ (void) setMaxLongRunningRequestsPerEndPoint:(NSUInteger)maxLongRunningRequestsPerEndPoint {
	if (maxLongRunningRequestsPerEndPoint > MAX_THREADS_PER_ENDPOINT)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Specified maximum number of concurrent long requests is bigger than pool size"
									 userInfo:@{@"poolSize": [NSNumber numberWithUnsignedInteger:MAX_THREADS_PER_ENDPOINT]}];
	
	__maxLongRunningRequestsPerEndPoint= maxLongRunningRequestsPerEndPoint;
}


#pragma mark -
#pragma mark Initialization

- (id) init {
	if ((self = [super init])) {
		
		// Initialization
		_decouplingThreadPoolsByEndPoint= [[NSMutableDictionary alloc] init];;
		
		_freeThreadsByEndPoint= [[NSMutableDictionary alloc] init];
		_busyThreadsByEndPoint= [[NSMutableDictionary alloc] init];

		_longRequestCountsByEndPoint= [[NSMutableDictionary alloc] init];
        
		_waitForFreeThread= [[NSCondition alloc] init];
        _nextThreadId= 1;
	}
	
	return self;
}

- (void) dealloc {
    // It's called in case if instance was created bypassing a sharedDispatcher initialization
    [__sharedDispatcher stopThreads];
}


#pragma mark -
#pragma mark URL request dispatching and checking

- (NSData *) dispatchSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse * __autoreleasing *)response error:(NSError * __autoreleasing *)error delegate:(id <LSURLDispatchDelegate>)delegate {
	if (!request)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Request can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForRequest:request];
	LSURLDispatchOperation *dispatchOp= [[LSURLDispatchOperation alloc] initWithURLRequest:request endPoint:endPoint delegate:delegate gatherData:YES isLong:NO];

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
	
	LSURLDispatchOperation *dispatchOp= [[LSURLDispatchOperation alloc] initWithURLRequest:request endPoint:endPoint delegate:delegate gatherData:NO isLong:NO];
	
	// Get the decoupling thread pool for this end-point
	LSThreadPool *pool= nil;
	@synchronized (_decouplingThreadPoolsByEndPoint) {
		pool= [_decouplingThreadPoolsByEndPoint objectForKey:endPoint];
		if (!pool) {
			NSString *poolName= [NSString stringWithFormat:@"LS URL Dispatcher Decoupling Thread Pool for end-point %@", endPoint];
			pool= [[LSThreadPool alloc] initWithName:poolName size:1];
			
			[_decouplingThreadPoolsByEndPoint setObject:pool forKey:endPoint];
		}
	}
	
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"scheduling short operation: %p for end-point: %@", dispatchOp, endPoint];
	
	// Scheduling the operation with the single-thread pool:
	// if a free connection thread for the end-point is not free
	// it will wait until one is freed
	[pool scheduleInvocationForBlock:^() {
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"starting short operation: %p for end-point: %@", dispatchOp, endPoint];
		
		[dispatchOp start];
	}];
	
	return dispatchOp;
}

- (LSURLDispatchOperation *) dispatchLongRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate {
	return [self dispatchLongRequest:request delegate:delegate ignoreMaxLongRunningRequestsLimit:NO];
}

- (LSURLDispatchOperation *) dispatchLongRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate ignoreMaxLongRunningRequestsLimit:(BOOL)ignoreMaxLongRunningRequestsLimit {
	if ((!request) || (!delegate))
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Request and/or delegate can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForRequest:request];

	// Check if there's room for another long running request
	NSUInteger count= 0;
	@synchronized (_longRequestCountsByEndPoint) {
		count= [[_longRequestCountsByEndPoint objectForKey:endPoint] unsignedIntegerValue];

		if ((count >= __maxLongRunningRequestsPerEndPoint) && (!ignoreMaxLongRunningRequestsLimit))
			@throw [NSException exceptionWithName:LS_TOO_MANY_LONG_RUNNING_REQUESTS
										   reason:@"Maximum number of concurrent long requests reached for end-point"
										 userInfo:@{@"endPoint": endPoint,
													@"count": [NSNumber numberWithUnsignedInteger:count]}];

		// Update long running request count
		count++;

		[_longRequestCountsByEndPoint setObject:[NSNumber numberWithUnsignedInteger:count] forKey:endPoint];
	}
	
	LSURLDispatchOperation *dispatchOp= [[LSURLDispatchOperation alloc] initWithURLRequest:request endPoint:endPoint delegate:delegate gatherData:NO isLong:YES];
	
	// Get the decoupling thread pool for this end-point
	LSThreadPool *pool= nil;
	@synchronized (_decouplingThreadPoolsByEndPoint) {
		pool= [_decouplingThreadPoolsByEndPoint objectForKey:endPoint];
		if (!pool) {
			NSString *poolName= [NSString stringWithFormat:@"LS URL Dispatcher Decoupling Thread Pool for end-point %@", endPoint];
			pool= [[LSThreadPool alloc] initWithName:poolName size:1];
			
			[_decouplingThreadPoolsByEndPoint setObject:pool forKey:endPoint];
		}
	}
	
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"scheduling long operation: %p for end-point: %@", dispatchOp, endPoint];
	
	// Scheduling the operation with the single-thread pool:
	// if a free connection thread for the end-point is not free
	// it will wait until one is freed
	[pool scheduleInvocationForBlock:^() {
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
    
    return [self isLongRequestAllowedToEndPoint:endPoint];
}

- (BOOL) isLongRequestAllowedToURL:(NSURL *)url {
	if (!url)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"URL can't be nil"
									 userInfo:nil];

	NSString *endPoint= [self endPointForURL:url];
    
    return [self isLongRequestAllowedToEndPoint:endPoint];
}

- (BOOL) isLongRequestAllowedToHost:(NSString *)host port:(int)port {
	if (!host)
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Host can't be nil"
									 userInfo:nil];
	
	NSString *endPoint= [self endPointForHost:host port:port];

    return [self isLongRequestAllowedToEndPoint:endPoint];
}


#pragma mark -
#pragma mark Thread pool management (for use by operations)

- (LSURLDispatcherThread *) preemptThreadForEndPoint:(NSString *)endPoint {
	LSURLDispatcherThread *thread= nil;
	
    NSUInteger poolSize= 0;
    NSUInteger activeSize= 0;
	do {
		@synchronized (_freeThreadsByEndPoint) {
			
			// Retrieve data structures
			NSMutableArray *freeThreads= [_freeThreadsByEndPoint objectForKey:endPoint];
			if (!freeThreads) {
				freeThreads= [[NSMutableArray alloc] init];

				[_freeThreadsByEndPoint setObject:freeThreads forKey:endPoint];
			}
			
			NSMutableArray *busyThreads= [_busyThreadsByEndPoint objectForKey:endPoint];
			if (!busyThreads) {
				busyThreads= [[NSMutableArray alloc] init];
				
				[_busyThreadsByEndPoint setObject:busyThreads forKey:endPoint];
			}
			
			// Get first free worker thread
			if ([freeThreads count] > 0) {
				thread= (LSURLDispatcherThread *) [freeThreads objectAtIndex:0];

				[freeThreads removeObjectAtIndex:0];
			}
			
			if (!thread) {
				
				// Check if we have to wait or create a new one
				if ([busyThreads count] < MAX(MAX_THREADS_PER_ENDPOINT, __maxLongRunningRequestsPerEndPoint)) {
					thread= [[LSURLDispatcherThread alloc] init];
					thread.name= [NSString stringWithFormat:@"LS URL Dispatcher Thread %d", _nextThreadId];
					
					[thread start];
					
					_nextThreadId++;
				}
			}

			if (thread) {
				[busyThreads addObject:thread];
			
				activeSize= [busyThreads count];
				poolSize= activeSize + [freeThreads count];
				break;
			}
		}
		
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"waiting for a free thread"];

		// If we've got here, we have to wait for a free thread and retry
		[_waitForFreeThread lock];
		[_waitForFreeThread wait];
		[_waitForFreeThread unlock];

	} while (YES);
	
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"preempted thread %p for end-point: %@, pool size is now: %lu (%lu active)", thread, endPoint, (unsigned long) poolSize, (unsigned long) activeSize];

	return thread;
}

- (void) releaseThread:(LSURLDispatcherThread *)thread forEndPoint:(NSString *)endPoint {
    NSUInteger poolSize= 0;
    NSUInteger activeSize= 0;
	@synchronized (_freeThreadsByEndPoint) {

		// Retrieve data structures
		NSMutableArray *freeThreads= [_freeThreadsByEndPoint objectForKey:endPoint];
		if (!freeThreads) {
			freeThreads= [[NSMutableArray alloc] init];
			
			[_freeThreadsByEndPoint setObject:freeThreads forKey:endPoint];
		}
		
		NSMutableArray *busyThreads= [_busyThreadsByEndPoint objectForKey:endPoint];
		if (!busyThreads) {
			busyThreads= [[NSMutableArray alloc] init];
			
			[_busyThreadsByEndPoint setObject:busyThreads forKey:endPoint];
		}

		// Release the thread
		[freeThreads addObject:thread];
		[busyThreads removeObject:thread];
        
        thread.lastActivity= [[NSDate date] timeIntervalSinceReferenceDate];
        
        activeSize= [busyThreads count];
        poolSize= activeSize + [freeThreads count];
	}
	
	// Signal there's a free thread
	[_waitForFreeThread lock];
	[_waitForFreeThread signal];
	[_waitForFreeThread unlock];
    
	// Reschedule idle thread collector
    [[LSTimerThread sharedTimer] cancelPreviousPerformRequestsWithTarget:self selector:@selector(collectIdleThreads)];
    [[LSTimerThread sharedTimer] performSelector:@selector(collectIdleThreads) onTarget:self afterDelay:THREAD_COLLECTOR_DELAY];
    
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"released thread %p for end-point: %@, pool size is now: %lu (%lu active)", thread, endPoint, (unsigned long) poolSize, (unsigned long) activeSize];
}

- (void) operationDidFinish:(LSURLDispatchOperation *)dispatchOp {
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
	
	if ([dispatchOp thread]) {
		
		// Release connection thread to thread pool
		[self releaseThread:[dispatchOp thread] forEndPoint:dispatchOp.endPoint];
	}
}


#pragma mark -
#pragma mark Thread management

- (void) collectIdleThreads {
	@synchronized (_freeThreadsByEndPoint) {
        NSTimeInterval now= [[NSDate date] timeIntervalSinceReferenceDate];
        
        for (NSString *endPoint in [_freeThreadsByEndPoint allKeys]) {
            NSMutableArray *freeThreads= [_freeThreadsByEndPoint objectForKey:endPoint];

            NSMutableArray *toBeCollected= [[NSMutableArray alloc] init];
            for (LSURLDispatcherThread *thread in freeThreads) {
                if ((now - thread.lastActivity) > MAX_THREAD_IDLENESS) {
                    [thread stopThread];
                    
                    [toBeCollected addObject:thread];
                }
            }
        
            [freeThreads removeObjectsInArray:toBeCollected];
        }
    }

	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"collected threads for all end-points"];
}

- (void) stopThreads {
	@synchronized (_freeThreadsByEndPoint) {
        for (NSMutableArray *freeThreads in [_freeThreadsByEndPoint allValues]) {
            for (LSURLDispatcherThread *thread in freeThreads)
                [thread stopThread];
        
            [freeThreads removeAllObjects];
        }
        
        for (NSMutableArray *busyThreads in [_busyThreadsByEndPoint allValues]) {
            for (LSURLDispatcherThread *thread in busyThreads)
                [thread stopThread];
        
            [busyThreads removeAllObjects];
        }
	}
    
	[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:self log:@"stopped all threads, pools are now empty"];
}


#pragma mark -
#pragma mark Internal methods

- (BOOL) isLongRequestAllowedToEndPoint:(NSString *)endPoint {
	NSUInteger count= 0;
    
	@synchronized (_longRequestCountsByEndPoint) {
		count= [[_longRequestCountsByEndPoint objectForKey:endPoint] unsignedIntegerValue];
	}
	
	return (count < __maxLongRunningRequestsPerEndPoint);
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
