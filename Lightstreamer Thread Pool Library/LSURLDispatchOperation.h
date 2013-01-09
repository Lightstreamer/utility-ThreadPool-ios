//
//  LSURLDispatchOperation.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LSURLDispatchDelegate.h"


@class LSURLDispatcherThread;
@class LSInvocation;

@interface LSURLDispatchOperation : NSObject {
	NSURLRequest *_request;
	NSString *_endPoint;
	id <LSURLDispatchDelegate> _delegate;
	BOOL _gathedData;
	BOOL _isLong;

	LSURLDispatcherThread *_thread;
	NSURLConnection *_connection;
	NSCondition *_waitForCompletion;
	
	NSURLResponse *_response;
	NSError *_error;
	NSMutableData *_data;
}


#pragma mark -
#pragma mark Initialization

- (id) initWithURLRequest:(NSURLRequest *)request endPoint:(NSString *)endPoint delegate:(id <LSURLDispatchDelegate>)delegate gatherData:(BOOL)gatherData isLong:(BOOL)isLong;


#pragma mark -
#pragma mark Execution

- (void) start;
- (void) waitForCompletion;
- (void) cancel;


#pragma mark -
#pragma mark Properties

@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) NSString *endPoint;
@property (nonatomic, readonly) BOOL isLong;

@property (nonatomic, readonly) LSURLDispatcherThread *thread;

@property (nonatomic, readonly) NSURLResponse *response;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) NSData *data;


@end
