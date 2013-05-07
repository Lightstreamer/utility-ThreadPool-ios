//
//  LSURLDispatcherThread.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 10/09/12.
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

#import "LSURLDispatcherThread.h"
#import "LSURLDispatcher.h"


@implementation LSURLDispatcherThread

#pragma mark -
#pragma mark Initialization

- (id) init {
    if ((self = [super init])) {
        
        // Initialization
        _running= YES;
		
		// Use a random loop time to avoid periodic delays
		int random= 0;
		SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
		_loopInterval= 1.0 + ((double) (ABS(random) % 2000)) / 1000.0;
    }
    
    return self;
}


#pragma mark -
#pragma mark Thread run loop

- (void) main {
	NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];
	
	NSRunLoop *runLoop= [NSRunLoop currentRunLoop];
	
	NSLog(@"LSURLDispatcherThread: thread %p started", self);
	
	do {
		NSAutoreleasePool *innerPool= [[NSAutoreleasePool alloc] init];
		
		@try {
			[runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:_loopInterval]];
			
		} @catch (NSException *e) {
			NSLog(@"LSURLDispatcherThread: exception caught while running thread %p run loop: %@", self, e);
			
		} @finally {
			[innerPool drain];
		}
		
	} while (_running);
	
	NSLog(@"LSURLDispatcherThread: thread %p stopped", self);
	
	[pool drain];
}


#pragma mark -
#pragma mark Execution control

- (void) stopThread {
    _running= NO;
}


#pragma mark -
#pragma mark Properties

@synthesize lastActivity= _lastActivity;



@end
