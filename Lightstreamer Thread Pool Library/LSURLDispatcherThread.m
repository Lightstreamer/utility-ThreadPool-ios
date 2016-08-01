//
//  LSURLDispatcherThread.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 10/09/12.
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

#import "LSURLDispatcherThread.h"
#import "LSURLDispatcher.h"
#import "LSLog.h"
#import "LSLog+Internals.h"


#pragma mark -
#pragma mark LSURLDispatcherThread extension

@interface LSURLDispatcherThread () {
    LSURLDispatcher __weak *_dispatcher;

    NSTimeInterval _loopInterval;
	
	NSTimeInterval _lastActivity;
	BOOL _running;
}


@end


#pragma mark -
#pragma mark LSURLDispatcherThread implementation

@implementation LSURLDispatcherThread


#pragma mark -
#pragma mark Initialization

- (instancetype) initWithDispatcher:(LSURLDispatcher *)dispatcher {
    if ((self = [super init])) {
        
        // Initialization
        _dispatcher= dispatcher;

        _running= YES;
		
		// Use a random loop time to avoid periodic delays
		int random= 0;
		int result= SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
        if (result == 0)
            _loopInterval= 1.0 + ((double) (ABS(random) % 2000)) / 1000.0;
        else
            _loopInterval= 2.1;
    }
    
    return self;
}


#pragma mark -
#pragma mark Thread run loop

- (void) main {
    @autoreleasepool {
        NSRunLoop *runLoop= [NSRunLoop currentRunLoop];
        
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"thread started", self.name];
		
        do {
            @autoreleasepool {
                @try {
                    BOOL ok= [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:_loopInterval]];
                    if (!ok) {
                        
                        // Should never happen, but just in case avoid CPU starvation
                        [NSThread sleepForTimeInterval:0.1];
                    }
                    
                } @catch (NSException *e) {
					[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"exception caught while running thread run loop: %@", self.name, e];
                }
            }
            
        } while (_running);
        
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:_dispatcher log:@"thread stopped", self.name];
    }
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
