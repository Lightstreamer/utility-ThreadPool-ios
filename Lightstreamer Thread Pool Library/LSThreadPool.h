//
//  LSThreadPool.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 17/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>


@class LSInvocation;

@interface LSThreadPool : NSObject {
	NSString *_name;
	int _size;

	NSMutableArray *_threads;

	NSMutableArray *_invocationQueue;
	NSCondition *_monitor;
	
    int _nextThreadId;
	BOOL _disposed;
}


#pragma mark -
#pragma mark Initialization

+ (LSThreadPool *) poolWithName:(NSString *)name size:(int)poolSize;
- (id) initWithName:(NSString *)name size:(int)poolSize;

- (void) dispose;


#pragma mark -
#pragma mark Invocation scheduling

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector;
- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector withObject:(id)object;


#pragma mark -
#pragma mark Properties

@property (nonatomic, readonly) int queueSize;


@end
