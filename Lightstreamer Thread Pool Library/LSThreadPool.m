//
//  LSThreadPool.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 17/09/12.
//  Copyright (c) 2012-2013 Weswit srl. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  * Neither the name of Weswit srl nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
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
	@synchronized (self) {

		// Check if there's a free thread
		BOOL freeThread= NO;
		for (LSThreadPoolThread *thread in _threads) {
			if (!thread.working)
				freeThread= YES;
		}
		
		if ((!freeThread) && ([_threads count] < _size)) {
			
			// No free threads, create a new one
			LSThreadPoolThread *thread= [LSThreadPoolThread threadWithPool:self
																	  name:[NSString stringWithFormat:@"LS Pool %@ Thread %d", _name, _nextThreadId]
																	 queue:_invocationQueue
															  queueMonitor:_monitor];
			
            _nextThreadId++;
			
			[_threads addObject:thread];
			
			poolSize= [_threads count];
		}
	}
	
	if (poolSize)
		NSLog(@"LSThreadPool: created new thread for pool %@, pool size is now %d", _name, poolSize);

	// Add invocation to queue
	[_monitor lock];
	
	LSInvocation *invocation= [LSInvocation invocationWithTarget:target selector:selector argument:object];
	[_invocationQueue addObject:invocation];
	
	[_monitor signal];
	[_monitor unlock];

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
			if ((now - thread.lastActivity) > MAX_THREAD_IDLENESS) {
				[thread dispose];
				
				[toBeCollected addObject:thread];
			}
		}
		
		[_threads removeObjectsInArray:toBeCollected];
		[toBeCollected release];
		
		poolSize= [_threads count];
    }
	
	NSLog(@"LSThreadPool: collected threads for for pool %@, pool size is now %d", _name, poolSize);
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
