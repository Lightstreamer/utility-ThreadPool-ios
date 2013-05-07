//
//  LSThreadPool.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 17/09/12.
//  Copyright 2013 Weswit Srl
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
#import "LSTimerThread.h"

#define MAX_THREAD_IDLENESS                                (10.0)
#define THREAD_COLLECTOR_DELAY                             (15.0)


@interface LSThreadPool ()


#pragma mark -
#pragma mark Thread management

- (void) collectIdleThreads;


@end


@implementation LSThreadPool


#pragma mark -
#pragma mark Initialization

+ (LSThreadPool *) poolWithName:(NSString *)name size:(int)poolSize {
	LSThreadPool *pool= [[LSThreadPool alloc] initWithName:name size:poolSize];
	
	return [pool autorelease];
}

- (id) initWithName:(NSString *)name size:(int)poolSize {
	if ((self = [super init])) {
		
		// Initialization
		_name= [name retain];
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
	
	[_name release];
	
	[_threads release];
	
	[_invocationQueue release];
	[_monitor release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Invocation scheduling

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector {
	return [self scheduleInvocationForTarget:target selector:selector withObject:nil];
}

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector withObject:(id)object {
	if (_disposed) {
		NSLog(@"LSThreadPool: can't schedule invocation: thread pool has already been disposed");
		
		return nil;
	}
	
	int poolSize= 0;
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
			newThread= [LSThreadPoolThread threadWithPool:self
													 name:[NSString stringWithFormat:@"LS Pool %@ Thread %d", _name, _nextThreadId]
													queue:_invocationQueue
											 queueMonitor:_monitor];
			
            _nextThreadId++;
			
			[_threads addObject:newThread];
			
			poolSize= [_threads count];
		}
	}
	
	if (newThread)
		NSLog(@"LSThreadPool: created new thread for pool %@, pool size is now %d", _name, poolSize);

	// Add invocation to queue
	[_monitor lock];
	
	LSInvocation *invocation= [LSInvocation invocationWithTarget:target selector:selector argument:object];
	[_invocationQueue addObject:invocation];
	
	[_monitor signal];
	[_monitor unlock];

	// Start the thread
	if (newThread)
		[newThread start];
	
	// Reschedule thread collector
    [[LSTimerThread sharedTimer] cancelPreviousPerformRequestsWithTarget:self selector:@selector(collectIdleThreads)];
    [[LSTimerThread sharedTimer] performSelector:@selector(collectIdleThreads) onTarget:self afterDelay:THREAD_COLLECTOR_DELAY];
	
	return invocation;
}


#pragma mark -
#pragma mark Thread management

- (void) collectIdleThreads {

	// Collect idle threads
	int poolSize= 0;
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
		[toBeCollected release];
		
		poolSize= [_threads count];
    }
	
	NSLog(@"LSThreadPool: collected threads for for pool %@, pool size is now %d", _name, poolSize);
	
	// Schedule new executions if there are still threads operating
	if (poolSize > 0)
		[[LSTimerThread sharedTimer] performSelector:@selector(collectIdleThreads) onTarget:self afterDelay:THREAD_COLLECTOR_DELAY];
}


#pragma mark -
#pragma mark Properties

@dynamic queueSize;

- (int) queueSize {
	@try {
		[_monitor lock];
		
		return [_invocationQueue count];

	} @finally {
		[_monitor unlock];
	}
}


@end
