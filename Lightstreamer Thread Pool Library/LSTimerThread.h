//
//  LSTimerThread.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 28/08/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LSTimerThread : NSObject {
	NSThread *_thread;
	BOOL _running;
}


#pragma mark -
#pragma mark Singleton management

+ (LSTimerThread *) sharedTimer;
+ (void) dispose;


#pragma mark -
#pragma mark Setting and removing timers

- (void) performSelector:(SEL)aSelector onTarget:(id)aTarget withObject:(id)anArgument afterDelay:(NSTimeInterval)delay;
- (void) performSelector:(SEL)aSelector onTarget:(id)aTarget afterDelay:(NSTimeInterval)delay;

- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument;
- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector;
- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget;


@end
