//
//  LSInvocation.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 18/09/12.
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

#import "LSInvocation.h"



#pragma mark -
#pragma mark LSInvocation extension

@interface LSInvocation () {
	id _target;
	SEL _selector;
	id _argument;
	NSTimeInterval _delay;
	
	LSInvocationBlock _block;
	
	NSCondition *_completionMonitor;
	BOOL _completed;
}


@end


#pragma mark -
#pragma mark LSInvocation implementation

@implementation LSInvocation


#pragma mark -
#pragma mark Initialization

+ (LSInvocation *) invocationWithBlock:(LSInvocationBlock)block {
	LSInvocation *invocation= [[LSInvocation alloc] initWithBlock:block];
	
	return invocation;
}

+ (LSInvocation *) invocationWithTarget:(id)target {
	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:nil argument:nil delay:0.0];
	
	return invocation;
}

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector {
	if (!selector) // Target is check in the initializer
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Selector can't be nil"
									 userInfo:nil];
	
	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:selector argument:nil delay:0.0];
	
	return invocation;
}

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector delay:(NSTimeInterval)delay {
	if (!selector) // Target is check in the initializer
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Selector can't be nil"
									 userInfo:nil];

	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:selector argument:nil delay:delay];
	
	return invocation;
}

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument {
	if (!selector) // Target is check in the initializer
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Selector can't be nil"
									 userInfo:nil];

	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:selector argument:argument delay:0.0];
	
	return invocation;
}

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument delay:(NSTimeInterval)delay {
	if (!selector) // Target is check in the initializer
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:@"Selector can't be nil"
									 userInfo:nil];
	
	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:selector argument:argument delay:delay];
	
	return invocation;
}

- (id) initWithBlock:(LSInvocationBlock)block {
	if ((self = [super init])) {
		
		// Initialization
		if (!block)
			@throw [NSException exceptionWithName:NSInvalidArgumentException
										   reason:@"Block can't be nil"
										 userInfo:nil];

		_block= [block copy];
	}
	
	return self;
}

- (id) initWithTarget:(id)target selector:(SEL)selector argument:(id)argument delay:(NSTimeInterval)delay {
	if ((self = [super init])) {
		
		// Initialization
		if (!target)
			@throw [NSException exceptionWithName:NSInvalidArgumentException
										   reason:@"Target can't be nil"
										 userInfo:nil];
		
		_target= target;
		_selector= selector;
		_argument= argument;
		_delay= delay;
	}
	
	return self;
}


#pragma mark -
#pragma mark Completion monitoring (for custom use)

- (void) waitForCompletion {
	BOOL toBeReleased= NO;

	@synchronized (self) {
		if (_completed)
			return;

		if (!_completionMonitor) {
			_completionMonitor= [[NSCondition alloc] init];
			toBeReleased= YES;
		}
	}
	
	[_completionMonitor lock];
	[_completionMonitor wait];
	[_completionMonitor unlock];
	
	if (toBeReleased)
		_completionMonitor= nil;
}

- (void) completed {
	@synchronized (self) {
		_completed= YES;
	}
	
	if (_completionMonitor) {
		[_completionMonitor lock];
		[_completionMonitor broadcast];
		[_completionMonitor unlock];
	}
}


#pragma mark -
#pragma mark Properties

@synthesize block= _block;
@synthesize target= _target;
@synthesize selector= _selector;
@synthesize argument= _argument;


@end
