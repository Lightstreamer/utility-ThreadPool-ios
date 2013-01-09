//
//  LSURLDispatcherThread.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 10/09/12.
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
