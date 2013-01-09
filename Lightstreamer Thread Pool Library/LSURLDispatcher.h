//
//  LSURLDispatcher.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
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
