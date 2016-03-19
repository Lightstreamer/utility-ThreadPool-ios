//
//  LSThreadPoolThread.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 18/09/12.
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

#import "LSThreadPoolThread.h"
#import "LSInvocation.h"
#import "LSLog.h"
#import "LSLog+Internals.h"


#pragma mark -
#pragma mark LSThreadPoolThread extension

@interface LSThreadPoolThread () {
	LSThreadPool * __weak _pool;
	NSMutableArray * __weak _queue;
	NSCondition * __weak _queueMonitor;
	
	NSTimeInterval _loopInterval;
	NSTimeInterval _lastActivity;
	BOOL _running;
	BOOL _working;
}


@end


#pragma mark -
#pragma mark LSThreadPoolThread implementation

@implementation LSThreadPoolThread


#pragma mark -
#pragma mark Initialization

- (instancetype) initWithPool:(LSThreadPool *)pool name:(NSString *)name queue:(NSMutableArray *)queue queueMonitor:(NSCondition *)queueMonitor {
	if ((self = [super init])) {
		
		// Initialization
		_pool= pool;
		_queue= queue;
		_queueMonitor= queueMonitor;
        
        self.name= name;
		
		// Use a random loop time to avoid periodic delays
		int random= 0;
		SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
		_loopInterval= 0.5 + ((double) (ABS(random) % 1000)) / 1000.0;
		
		_running= YES;
		_working= YES;
	}
	
	return self;
}

- (void) dealloc {
	[self dispose];
}

- (void) dispose {
	_running= NO;
}


#pragma mark -
#pragma mark Thread run loop

- (void) main {
    @autoreleasepool {
	
        // Local retain: they could be released while the thread is running
        NSString *name= self.name;
        NSMutableArray *queue= _queue;
        NSCondition *monitor= _queueMonitor;
        
        @try {
            while (_running) {
                @autoreleasepool {
                    LSInvocation *invocation= nil;
                    @try {
                        [monitor lock];
                        
                        if ([queue count] == 0) {
                            _working= NO;

                            [monitor waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:_loopInterval]];
                            
                            _working= YES;
                        }
                        
                        if ([queue count] > 0) {
                            invocation= [queue objectAtIndex:0];
                            
                            [queue removeObjectAtIndex:0];
                        }
                        
                        [monitor unlock];
                        
                        if (invocation) {
                            @try {
                                if (invocation.target) {
                                    if (invocation.argument) {
                                        
                                        // Find method implementation and call it
                                        IMP imp= [invocation.target methodForSelector:invocation.selector];
                                        void (*func)(id, SEL, id)= (void *) imp;
                                        func(invocation.target, invocation.selector, invocation.argument);

                                    } else {
                                        
                                        // Find method implementation and call it
                                        IMP imp= [invocation.target methodForSelector:invocation.selector];
                                        void (*func)(id, SEL)= (void *) imp;
                                        func(invocation.target, invocation.selector);
                                    }

                                } else if (invocation.block) {
                                    invocation.block();
                                }
                                
                            } @catch (NSException *ee) {
								[LSLog sourceType:LOG_SRC_THREAD_POOL source:_pool log:@"exception caught while performing invocation on thread pool %@: %@ (user info: %@)", name, ee, ee.userInfo];
                            }
                            
                            _lastActivity= [[NSDate date] timeIntervalSinceReferenceDate];
                        }
                        
                    } @catch (NSException *e) {
						[LSLog sourceType:LOG_SRC_THREAD_POOL source:_pool log:@"exception caught while running thread pool %@: %@ (user info: %@)", name, e, e.userInfo];
						
                    } @finally {
                        invocation= nil;
                    }
                }
            }
            
        } @finally {
            name= nil;
            queue= nil;
            monitor= nil;
        }
    }
}


#pragma mark -
#pragma mark Properties

@synthesize working= _working;
@synthesize lastActivity= _lastActivity;


@end
