//
//  LSTimerThread.m
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 28/08/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import "LSTimerThread.h"
#import "LSInvocation.h"
#import "LSLog.h"


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
	
	if ([LSLog isSourceTypeEnabled:LOG_SRC_TIMER])
		[LSLog sourceType:LOG_SRC_TIMER source:self log:@"thread started"];
	
	do {
		NSAutoreleasePool *innerPool= [[NSAutoreleasePool alloc] init];
		
		NSTimer *timer= [NSTimer timerWithTimeInterval:5.3 target:self selector:@selector(threadHeartBeat) userInfo:nil repeats:NO];
		@try {
			[loop addTimer:timer forMode:NSDefaultRunLoopMode];
			
			[loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:4.7]];
			
			[timer invalidate];
			
		} @catch (NSException *e) {
			if ([LSLog isSourceTypeEnabled:LOG_SRC_TIMER])
				[LSLog sourceType:LOG_SRC_TIMER source:self log:@"exception caught while running thread run loop: %@", e];
			
		} @finally {
			[innerPool drain];
		}
		
	} while (_running);
	
	if ([LSLog isSourceTypeEnabled:LOG_SRC_TIMER])
		[LSLog sourceType:LOG_SRC_TIMER source:self log:@"thread stopped"];
	
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
