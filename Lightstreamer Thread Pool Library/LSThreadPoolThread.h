//
//  LSThreadPoolThread.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 18/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>


@class LSThreadPool;

@interface LSThreadPoolThread : NSThread {
	LSThreadPool *_pool;
	NSString *_name;
	NSMutableArray *_queue;
	NSCondition *_queueMonitor;
	
	NSTimeInterval _loopInterval;
    NSTimeInterval _lastActivity;
	BOOL _running;
	BOOL _working;
}


#pragma mark -
#pragma mark Initialization

+ (LSThreadPoolThread *) threadWithPool:(LSThreadPool *)pool name:(NSString *)name queue:(NSMutableArray *)queue queueMonitor:(NSCondition *)queueMonitor;
- (id) initWithPool:(LSThreadPool *)pool name:(NSString *)name queue:(NSMutableArray *)queue queueMonitor:(NSCondition *)queueMonitor;

- (void) dispose;


#pragma mark -
#pragma mark Properties

@property (nonatomic, assign) BOOL working;
@property (nonatomic, assign) NSTimeInterval lastActivity;


@end
