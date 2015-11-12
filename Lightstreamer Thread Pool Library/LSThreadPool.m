//
//  LSThreadPool.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 17/09/12.
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

#import "LSThreadPool.h"
#import "LSThreadPoolThread.h"
#import "LSInvocation.h"
#import "LSInvocation+Internals.h"
#import "LSTimerThread.h"
#import "LSLog.h"
#import "LSLog+Internals.h"

#define MAX_THREAD_IDLENESS                                (10.0)
#define THREAD_COLLECTOR_DELAY                             (15.0)

#define LS_THREAD_POOL_DISPOSED_OF                         (@"LSThreadPoolDisposedOf")


#pragma mark -
#pragma mark LSThreadPool extension

@interface LSThreadPool () {
	NSString *_name;
	NSUInteger _size;
	
	NSMutableArray *_threads;
	
	NSMutableArray *_invocationQueue;
	NSCondition *_monitor;
	
	int _nextThreadId;
	BOOL _disposed;
}


#pragma mark -
#pragma mark Internal

- (void) scheduleInvocation:(LSInvocation *)invocation;


#pragma mark -
#pragma mark Thread management

- (void) collectIdleThreads;


@end


#pragma mark -
#pragma mark LSThreadPool implementation

@implementation LSThreadPool


#pragma mark -
#pragma mark Initialization

+ (LSThreadPool *) poolWithName:(NSString *)name size:(NSUInteger)poolSize {
	LSThreadPool *pool= [[LSThreadPool alloc] initWithName:name size:poolSize];
	
	return pool;
}

- (instancetype) initWithName:(NSString *)name size:(NSUInteger)poolSize {
	if ((self = [super init])) {
		
		// Initialization
		if ((!name) || (!poolSize))
			@throw [NSException exceptionWithName:NSInvalidArgumentException
										   reason:@"Thread pool name can't be nil and pool size must be greater than 0"
										 userInfo:nil];
		
		_name= name;
		_size= poolSize;
		
		_threads= [[NSMutableArray alloc] initWithCapacity:_size];
		
		_invocationQueue= [[NSMutableArray alloc] init];
		_monitor= [[NSCondition alloc] init];
		
		_nextThreadId= 1;
	}
	
	return self;
}

- (void) dispose {
	_disposed= YES;

	@synchronized (self) {
		for (LSThreadPoolThread *thread in _threads)
			[thread dispose];

		[_threads removeAllObjects];
	}

	[_monitor lock];
	[_monitor broadcast];
	[_monitor unlock];
}

- (void) dealloc {
	[self dispose];
}


#pragma mark -
#pragma mark Invocation scheduling

- (LSInvocation *) scheduleInvocationForBlock:(LSInvocationBlock)block {
	LSInvocation *invocation= [LSInvocation invocationWithBlock:block];
	
	[self scheduleInvocation:invocation];
	return invocation;
}

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector {
	LSInvocation *invocation= [LSInvocation invocationWithTarget:target selector:selector];
	
	[self scheduleInvocation:invocation];
	return invocation;
}

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector withObject:(id)object {
	LSInvocation *invocation= [LSInvocation invocationWithTarget:target selector:selector argument:object];
	
	[self scheduleInvocation:invocation];
	return invocation;
}


#pragma mark -
#pragma mark Internals

- (void) scheduleInvocation:(LSInvocation *)invocation {
	if (_disposed)
		@throw [NSException exceptionWithName:LS_THREAD_POOL_DISPOSED_OF
									   reason:@"Can't schedule invocation: thread pool has already been disposed"
									 userInfo:@{@"threadPoolName": _name}];
	
	NSUInteger poolSize= 0;
	LSThreadPoolThread *newThread= nil;
	@synchronized (self) {

		// Check if there's a free thread
		BOOL freeThread= NO;
		for (LSThreadPoolThread *thread in _threads) {
			if (!(thread.working)) {
				freeThread= YES;
				break;
			}
		}
		
		if ((!freeThread) && ([_threads count] < _size)) {
			
			// No free threads, create a new one
			newThread= [[LSThreadPoolThread alloc] initWithPool:self
														   name:[NSString stringWithFormat:@"LS Pool %@ Thread %d", _name, _nextThreadId]
														  queue:_invocationQueue
												   queueMonitor:_monitor];
			
            _nextThreadId++;
			
			[_threads addObject:newThread];
			
			poolSize= [_threads count];
		}
	}
	
	if (newThread)
		[LSLog sourceType:LOG_SRC_THREAD_POOL source:self log:@"created new thread for pool %@, pool size is now: %lu", _name, (unsigned long) poolSize];

	// Add invocation to queue
	[_monitor lock];
	
	[_invocationQueue addObject:invocation];
	
	[_monitor signal];
	[_monitor unlock];
	
	// Start the thread
	if (newThread)
		[newThread start];

	// Reschedule thread collector
    [[LSTimerThread sharedTimer] cancelPreviousPerformRequestsWithTarget:self selector:@selector(collectIdleThreads)];
    [[LSTimerThread sharedTimer] performSelector:@selector(collectIdleThreads) onTarget:self afterDelay:THREAD_COLLECTOR_DELAY];
}


#pragma mark -
#pragma mark Thread management

- (void) collectIdleThreads {

	// Collect idle threads
	NSUInteger poolSize= 0;
	@synchronized (self) {
        NSTimeInterval now= [[NSDate date] timeIntervalSinceReferenceDate];
		
		NSMutableArray *toBeCollected= [[NSMutableArray alloc] init];
		for (LSThreadPoolThread *thread in _threads) {
			if ((!(thread.working)) && ((now - thread.lastActivity) > MAX_THREAD_IDLENESS)) {
				[thread dispose];
				
				[toBeCollected addObject:thread];
			}
		}
		
		[_threads removeObjectsInArray:toBeCollected];
		
		poolSize= [_threads count];
    }
	
	[LSLog sourceType:LOG_SRC_THREAD_POOL source:self log:@"collected threads for pool %@, pool size is now: %lu", _name, (unsigned long) poolSize];
	
	// Schedule new executions if there are still threads operating
	if (poolSize > 0)
		[[LSTimerThread sharedTimer] performSelector:@selector(collectIdleThreads) onTarget:self afterDelay:THREAD_COLLECTOR_DELAY];
}


#pragma mark -
#pragma mark Properties

@dynamic queueSize;

- (NSUInteger) queueSize {
	@try {
		[_monitor lock];
		
		return [_invocationQueue count];

	} @finally {
		[_monitor unlock];
	}
}


@end
