//
//  LSURLDispatcher.h
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


@class LSURLDispatchOperation;
@class LSURLDispatcherThread;
@protocol LSURLDispatchDelegate;

/**
 @brief LSURLDispatcher is a singleton object providing URL connection services on fixed connection pools divided by end-point.
 <br/> By using fixed pools, it guarantees that the connection limit imposed by the system is never exceeded. If the connection pool 
 for a certain end-point is exhausted, it may either put the calling thread to wait or refuse the request by throwing an exception,
 depending on the type of connection requested.
 <br/> Connection requests may be of 1 of 3 different types: <ul>
 <li> <b>synchronous request</b>: keeps the calling thread suspended and return only with a complete NSData or NSError;
 <li> <b>short request</b>: detaches from the calling thread and works asynchronously with a specified delegate;
 <li> <b>long request</b>: detaches from the calling thread and works asynchronously, like short connections, but their number
 is further monitored to avoid a connection pool congestion.
 </ul>
 <br/> Given these 3 types of requests, the expected usage pattern is the following: <ul>
 <li> synchronous and short requests should be used for short request-reply roundtrips that are expected to last for a few seconds.
 <br/> Their concurrency is limited by the connection pool size (i.e. 4 by factory setting), and if a fifth connection is requested the
 calling thread is put to wait until a connection is freed;
 <li> long requests should be used only for long running connections, such as data streaming, audio streaming, VoIPs, videos, etc.
 <br/> Their concurrency is further limited by configuration (2 by default, so to always keep 2 spare connections for short and synchronous
 requests), and the LSURLDispatcher can tell if another long running connection can be requested or not; if it can't and it is
 requested anyway, an exception is thrown.
 </ul>
 <br/> Connection threads are created on-demand and recycled up to 10 seconds after a thread has been freed. Every 15 seconds
 a collector passes and disposes of threads remained on idle since more than 10 seconds.
*/
@interface LSURLDispatcher : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>


#pragma mark -
#pragma mark Singleton management

/**
 @brief Accessor for the LSURLDispatcher singleton.
 <br/> At the first call the singleton is initialized.
 @return The LSURLDispatcher singleton.
 */
+ (nonnull LSURLDispatcher *) sharedDispatcher;

/**
 @brief Disposes of the current LSURLDispatcher singleton.
 <br/> If <code>sharedDispatcher</code> is called again after <code>dispose</code>, a new singleton is initialized.
 */
+ (void) dispose;


#pragma mark -
#pragma mark Class properties

/**
 @brief Getter for the currently configured maximum number of concurrent long running requests.
 <br/> Default value is 2.
 @return The current maximum number of concurrent long running requests
 */
+ (NSUInteger) maxLongRunningRequestsPerEndPoint;

/**
 @brief Setter for the maximum number of concurrent long running requests.
 @throws NSException If the specified number is bigger than the connection pool size.
 */
+ (void) setMaxLongRunningRequestsPerEndPoint:(NSUInteger)maxLongRunningRequestsPerEndPoint;

/**
 @brief Getter for the currently configured flag of use of NSURLSession.
 <br/> If <code>YES</code> and running on iOS 7.0 or greater, or OS X 10.9 or greater, the LSURLDispatcher makes use
 of a common NSURLSession and a separate NSURLSessionDataTask for each dispatch operation. If <code>NO</code>,
 the LSURLDispatcher reverts to NSURLConnections even on iOS 7.0 or greater, or OS X 10.9 or greater.
 <br/> NOTE: make sure to set this value before initialization (i.e. before the first time the singleton is accessed).
 <br/> Default value is <code>YES</code>
 @return The currently configured flag of use of NSURLSession.
 */
+ (BOOL) useNSURLSessionIfAvailable;

/**
 @brief Setter for the flag of use of NSURLSession.
 <br/> If <code>YES</code> and running on iOS 7.0 or greater, or OS X 10.9 or greater, the LSURLDispatcher makes use
 of a common NSURLSession and a separate NSURLSessionDataTask for each dispatch operation. If <code>NO</code>,
 the LSURLDispatcher reverts to NSURLConnections even on iOS 7.0 or greater, or OS X 10.9 or greater.
 <br/> This value is checked only during initialization (i.e. the first time the singleton is accessed).
 <br/> Default value is <code>YES</code>
 @return The currently configured flag of use of NSURLSession.
 */
+ (void) setUseNSURLSessionIfAvailable:(BOOL)use;


#pragma mark -
#pragma mark URL request dispatching and checking

/**
 @brief Starts a synchronous request and waits for its completion.
 <br/> If the connection pool is exhausted, the calling thread is put to wait until a connection is freed.
 @param request The URL request to be submitted.
 <br/> Note: the timeout interval specified on the request is honored and enforced.
 @param response The HTTP URL response as returned by the end-point.
 @param error If passed, may be filled with an NSError is case of a connection error.
 @param delegate If passed, it is called as the connection request progresses in its completion.
 @return The body of the HTTP response.
 @throws NSException If the request is <code>nil</code>.
 */
- (nullable NSData *) dispatchSynchronousRequest:(nonnull NSURLRequest *)request returningResponse:(NSURLResponse * __autoreleasing __nullable * __nullable)response error:(NSError * __autoreleasing __nullable * __nullable)error delegate:(nullable id <LSURLDispatchDelegate>)delegate;

/**
 @brief Starts a short request and runs it asynchronously.
 @param request The URL request to be submitted.
 <br/> Note: the timeout interval specified on the request is honored and enforced.
 @param delegate The delegate to be called as the connection request progresses in its completion.
 @return A descriptor of the ongoing URL request operation.
 @throws NSException If request and/or delegate are <code>nil</code>.
 */
- (nonnull LSURLDispatchOperation *) dispatchShortRequest:(nonnull NSURLRequest *)request delegate:(nonnull id <LSURLDispatchDelegate>)delegate;

/**
 @brief Starts a long request and runs it asynchronously.
 <br/> If the maximum long running request limit is exceeded throws an exception.
 @param request The URL request to be submitted.
 <br/> Note: the timeout interval specified on the request is honored and enforced.
 @param delegate The delegate to be called as the connection request progresses in its completion.
 @return A descriptor of the ongoing URL request operation.
 @throws NSException If the maximum long running request limit is exceeded.
 @throws NSException If request and/or delegate are <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (nonnull LSURLDispatchOperation *) dispatchLongRequest:(nonnull NSURLRequest *)request delegate:(nonnull id <LSURLDispatchDelegate>)delegate;

/**
 @brief Starts a long request and runs it asynchronously.
 <br/> If the maximum long running request limit is exceeded either throws an exception or not,
 depending on the <code>ignoreMaxLongRunningRequestsLimit</code> param.
 @param request The URL request to be submitted.
 <br/> Note: the timeout interval specified on the request is honored and enforced.
 @param delegate The delegate to be called as the connection request progresses in its completion.
 @param ignoreMaxLongRunningRequestsLimit If set to <code>YES</code> will avoid throwing an exception if the
 maximum long running request limit is exceeded. 
 <br/> May be used in special cases where an exceptional long request for a certain end-point must be submitted in any case, 
 but the limit must remain intact for other end-points.
 @return A descriptor of the ongoing URL request operation.
 @throws NSException If the maximum long running request limit is exceeded and the <code>ignoreMaxLongRunningRequestsLimit</code> 
 parameter is not set.
 @throws NSException If request and/or delegate are <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (nonnull LSURLDispatchOperation *) dispatchLongRequest:(nonnull NSURLRequest *)request delegate:(nonnull id <LSURLDispatchDelegate>)delegate ignoreMaxLongRunningRequestsLimit:(BOOL)ignoreMaxLongRunningRequestsLimit;

/**
 @brief Checks if the end-point specified by the request currently has at least a spare long running connection to be used.
 @param request The URL request to be checked.
 @return <code>YES</code> if the end-point has a spare long running connection.
 @throws NSException If the request is <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (BOOL) isLongRequestAllowed:(nonnull NSURLRequest *)request;

/**
 @brief Checks if the end-point specified by the URL currently has at least a spare long running connection to be used.
 @param url The URL to be checked.
 @return <code>YES</code> if the end-point has a spare long running connection.
 @throws NSException If the URL is <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (BOOL) isLongRequestAllowedToURL:(nonnull NSURL *)url;

/**
 @brief Checks if the end-point specified currently has at least a spare long running connection to be used.
 @param host The host of the end-point to be checked.
 @param port The port of the end-point to be checked.
 @return <code>YES</code> if the end-point has a spare long running connection.
 @throws NSException If the host is <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (BOOL) isLongRequestAllowedToHost:(nonnull NSString *)host port:(int)port;


@end
