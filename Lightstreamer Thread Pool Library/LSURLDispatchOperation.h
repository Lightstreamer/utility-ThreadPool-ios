//
//  LSURLDispatchOperation.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 03/09/12.
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

#import <Foundation/Foundation.h>
#import "LSURLDispatchDelegate.h"


@class LSURLDispatcherThread;
@class LSInvocation;

/**
 @brief LSURLDispatchOperation describes an ongoing URL request operation.
 <br/> Provides a service to cancel the request.
 */
@interface LSURLDispatchOperation : NSObject


#pragma mark -
#pragma mark Request canceling

/**
 @brief Cancels the URL request operation, freeing the connection.
 <br/> The call is executed on a background thread. So it returns immeditaly, byt the operation may keep going for a while 
 before it is actually cancelled.
 */
- (void) cancel;


#pragma mark -
#pragma mark Properties

/**
 @brief The original URL request for this operation.
 */
@property (nonatomic, readonly, nonnull) NSURLRequest *request;

/**
 @brief The URL request end-point, expressed as "host:port".
 */
@property (nonatomic, readonly, nonnull) NSString *endPoint;

/**
 @brief If the URL request operation has been started as a long running request.
 */
@property (nonatomic, readonly) BOOL isLong;

/**
 @brief The HTTP URL response as returned by the end-point.
 <br/> Initially nil, it is filled as the URL request operation progresses.
 */
@property (nonatomic, readonly, nullable) NSURLResponse *response;

/**
 @brief An eventual connection error, if the URL request operation cannot be completed.
 */
@property (nonatomic, readonly, nullable) NSError *error;

/**
 @brief When using synchronous requests, contains the body of the HTTP response.
 <br/> Initially nil, it is filled as the URL request operation progresses. When using short or long requests,
 this value remains nil (i.e. collecting the data is up to the delegate).
 */
@property (nonatomic, readonly, nullable) NSData *data;


@end
