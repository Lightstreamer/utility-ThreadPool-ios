//
//  LSURLDispatcherThread.m
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 10/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import "LSURLDispatcherThread.h"
#import "LSURLDispatcher.h"
#import "LSLog.h"


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
	
	if ([LSLog isSourceTypeEnabled:LOG_SRC_URL_DISPATCHER])
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:[LSURLDispatcher sharedDispatcher] log:@"thread %p started", self];
	
	do {
		NSAutoreleasePool *innerPool= [[NSAutoreleasePool alloc] init];
		
		@try {
			[runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:_loopInterval]];
			
		} @catch (NSException *e) {
			if ([LSLog isSourceTypeEnabled:LOG_SRC_URL_DISPATCHER])
				[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:[LSURLDispatcher sharedDispatcher] log:@"exception caught while running thread %p run loop: %@", self, e];
			
		} @finally {
			[innerPool drain];
		}
		
	} while (_running);
	
	if ([LSLog isSourceTypeEnabled:LOG_SRC_URL_DISPATCHER])
		[LSLog sourceType:LOG_SRC_URL_DISPATCHER source:[LSURLDispatcher sharedDispatcher] log:@"thread %p stopped", self];
	
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
