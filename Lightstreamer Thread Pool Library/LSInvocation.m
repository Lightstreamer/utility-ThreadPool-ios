//
//  LSInvocation.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 18/09/12.
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

#import "LSInvocation.h"


@implementation LSInvocation


#pragma mark -
#pragma mark Initialization

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector {
	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:selector argument:nil];
	
	return [invocation autorelease];
}

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument {
	LSInvocation *invocation= [[LSInvocation alloc] initWithTarget:target selector:selector argument:argument];
	
	return [invocation autorelease];
}

- (id) initWithTarget:(id)target selector:(SEL)selector argument:(id)argument {
	if ((self = [super init])) {
		
		// Initialization
		_target= [target retain];
		_selector= selector;
		_argument= [argument retain];
	}
	
	return self;
}

- (void) dealloc {
	[_target release];
	[_argument release];
	
	[super dealloc];
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
	
	if (toBeReleased) {
		[_completionMonitor release];
		_completionMonitor= nil;
	}
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

@synthesize target= _target;
@synthesize selector= _selector;
@synthesize argument= _argument;


@end
