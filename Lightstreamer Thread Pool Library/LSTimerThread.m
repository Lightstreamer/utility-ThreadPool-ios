//
//  LSTimerThread.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 28/08/12.
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

#import "LSTimerThread.h"
#import "LSInvocation.h"


#pragma mark -
#pragma mark Extension of LSTimerThread

@interface LSTimerThread ()


#pragma mark -
#pragma mark Setting and removing timers on timer thread

- (void) threadPerformDelayedInvocation:(NSDictionary *)invocationInfo;
- (void) threadCancelPreviousDelayedPerformWithInfo:(NSDictionary *)invocationInfo;


#pragma mark -
#pragma mark Thread run loop

- (void) threadRunLoop;
- (void) threadHeartBeat;

- (void) stopThread;


@end


static LSTimerThread *__sharedTimer= nil;

@implementation LSTimerThread


#pragma mark -
#pragma mark Singleton management

+ (LSTimerThread *) sharedTimer {
	if (__sharedTimer)
		return __sharedTimer;
	
	@synchronized ([LSTimerThread class]) {
		if (!__sharedTimer)
			__sharedTimer= [[LSTimerThread alloc] init];
	}
	
	return __sharedTimer;
}

+ (void) dispose {
	if (!__sharedTimer)
		return;
	
	@synchronized ([LSTimerThread class]) {
		if (__sharedTimer) {
			[__sharedTimer stopThread];
			
			[__sharedTimer release];
			__sharedTimer= nil;
		}
	}
}


#pragma mark -
#pragma mark Initialization

- (id) init {
	if ((self = [super init])) {
		
		// Initialization
		_running= YES;
		
		_thread= [[NSThread alloc] initWithTarget:self selector:@selector(threadRunLoop) object:nil];
		_thread.name= [NSString stringWithFormat:@"LS Timer Thread"];
		
		[_thread start];
	}
	
	return self;
}

- (void) dealloc {
	[LSTimerThread dispose];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Setting and removing timers

- (void) performSelector:(SEL)aSelector onTarget:(id)aTarget withObject:(id)anArgument afterDelay:(NSTimeInterval)delay {
	LSInvocation *invocation= [LSInvocation invocationWithTarget:aTarget selector:aSelector argument:anArgument];

	NSDictionary *invocationInfo= [NSDictionary dictionaryWithObjectsAndKeys:
								   invocation, @"invocation",
								   [NSNumber numberWithDouble:delay], @"delay",
								   nil];
	
	[self performSelector:@selector(threadPerformDelayedInvocation:) onThread:_thread withObject:invocationInfo waitUntilDone:NO];
}

- (void) performSelector:(SEL)aSelector onTarget:(id)aTarget afterDelay:(NSTimeInterval)delay {
	LSInvocation *invocation= [LSInvocation invocationWithTarget:aTarget selector:aSelector];

	NSDictionary *invocationInfo= [NSDictionary dictionaryWithObjectsAndKeys:
								   invocation, @"invocation",
								   [NSNumber numberWithDouble:delay], @"delay",
								   nil];
	
	[self performSelector:@selector(threadPerformDelayedInvocation:) onThread:_thread withObject:invocationInfo waitUntilDone:NO];
}

- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument {
	LSInvocation *invocation= [LSInvocation invocationWithTarget:aTarget selector:aSelector argument:anArgument];
	
	NSDictionary *invocationInfo= [NSDictionary dictionaryWithObjectsAndKeys:
								   invocation, @"invocation",
								   nil];
	
	[self performSelector:@selector(threadCancelPreviousDelayedPerformWithInfo:) onThread:_thread withObject:invocationInfo waitUntilDone:NO];
}

- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector {
	LSInvocation *invocation= [LSInvocation invocationWithTarget:aTarget selector:aSelector];

	NSDictionary *invocationInfo= [NSDictionary dictionaryWithObjectsAndKeys:
								   invocation, @"invocation",
								   nil];
	
	[self performSelector:@selector(threadCancelPreviousDelayedPerformWithInfo:) onThread:_thread withObject:invocationInfo waitUntilDone:NO];
}

- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget {
	NSDictionary *invocationInfo= [NSDictionary dictionaryWithObjectsAndKeys:
								   aTarget, @"target",
								   nil];
	
	[self performSelector:@selector(threadCancelPreviousDelayedPerformWithInfo:) onThread:_thread withObject:invocationInfo waitUntilDone:NO];
}


#pragma mark -
#pragma mark Setting and removing timers on timer thread

- (void) threadPerformDelayedInvocation:(NSDictionary *)invocationInfo {
	LSInvocation *invocation= [invocationInfo objectForKey:@"invocation"];
	NSTimeInterval delay= [[invocationInfo objectForKey:@"delay"] doubleValue];

	[invocation.target performSelector:invocation.selector withObject:invocation.argument afterDelay:delay];
}

- (void) threadCancelPreviousDelayedPerformWithInfo:(NSDictionary *)invocationInfo {
	LSInvocation *invocation= [invocationInfo objectForKey:@"invocation"];
	if (invocation) {
		[NSObject cancelPreviousPerformRequestsWithTarget:invocation.target selector:invocation.selector object:invocation.argument];
		
	} else {
		id target= [invocationInfo objectForKey:@"target"];

		[NSObject cancelPreviousPerformRequestsWithTarget:target];
	}
}


#pragma mark -
#pragma mark Thread run loop

- (void) threadRunLoop {
	NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];
	
	NSRunLoop *loop= [NSRunLoop currentRunLoop];
	
	NSLog(@"LSTimerThread: thread started");
	
	do {
		NSAutoreleasePool *innerPool= [[NSAutoreleasePool alloc] init];
		
		NSTimer *timer= [NSTimer timerWithTimeInterval:5.3 target:self selector:@selector(threadHeartBeat) userInfo:nil repeats:NO];
		@try {
			[loop addTimer:timer forMode:NSDefaultRunLoopMode];
			
			[loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:4.7]];
			
			[timer invalidate];
			
		} @catch (NSException *e) {
			NSLog(@"LSTimerThread: exception caught while running thread run loop: %@", e);
			
		} @finally {
			[innerPool drain];
		}
		
	} while (_running);
	
	NSLog(@"LSTimerThread: thread stopped");
	
	[pool drain];
}

- (void) threadHeartBeat {
	
	// Dummy method to keep the run loop busy
}

- (void) stopThread {
	_running= NO;
	
	[_thread release];
	_thread= nil;
}


@end
