//
//  LSURLDispatcher.h
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


@class LSURLDispatchOperation;
@class LSURLDispatcherThread;
@protocol LSURLDispatchDelegate;

@interface LSURLDispatcher : NSObject {
	NSMutableDictionary *_freeThreadsByEndPoint;
	NSMutableDictionary *_busyThreadsByEndPoint;
    
	NSMutableDictionary *_longRequestCountsByEndPoint;
	
	NSCondition *_waitForFreeThread;
    int _nextThreadId;
}


#pragma mark -
#pragma mark Singleton management

+ (LSURLDispatcher *) sharedDispatcher;
+ (void) dispose;


#pragma mark -
#pragma mark Thread pool management and notifications (for use by operations)

- (LSURLDispatcherThread *) preemptThreadForEndPoint:(NSString *)endPoint;
- (void) releaseThread:(LSURLDispatcherThread *)thread forEndPoint:(NSString *)endPoint;

- (void) operationDidFinish:(LSURLDispatchOperation *)dispatchOp;


#pragma mark -
#pragma mark URL request dispatching and checking

- (NSData *) dispatchSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error;
- (LSURLDispatchOperation *) dispatchLongRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate;
- (LSURLDispatchOperation *) dispatchShortRequest:(NSURLRequest *)request delegate:(id <LSURLDispatchDelegate>)delegate;

- (BOOL) isLongRequestAllowed:(NSURLRequest *)request;
- (BOOL) isLongRequestAllowedToURL:(NSURL *)url;
- (BOOL) isLongRequestAllowedToHost:(NSString *)host port:(int)port;


@end
