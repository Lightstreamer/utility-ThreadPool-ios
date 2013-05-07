//
//  LSURLDispatchOperation.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 03/09/12.
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
