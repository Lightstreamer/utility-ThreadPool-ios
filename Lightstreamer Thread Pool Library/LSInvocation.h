//
//  LSInvocation.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 18/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LSInvocation : NSObject {
	id _target;
	SEL _selector;
	id _argument;
	
	NSCondition *_completionMonitor;
	BOOL _completed;
}


#pragma mark -
#pragma mark Initialization

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector;
+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument;

- (id) initWithTarget:(id)target selector:(SEL)selector argument:(id)argument;


#pragma mark -
#pragma mark Completion monitoring (for custom use)

- (void) waitForCompletion;
- (void) completed;


#pragma mark -
#pragma mark Properties

@property (nonatomic, readonly) id target;
@property (nonatomic, readonly) SEL selector;
@property (nonatomic, readonly) id argument;


@end
