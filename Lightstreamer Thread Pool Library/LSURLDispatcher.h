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


/**
 @brief Policy to be used when the limit for long requests is exceeded.
 <br/> Used by <code>dispatchLongRequest:delegate:policy:</code>.
 */
typedef NS_ENUM(NSUInteger, LSLongRequestLimitExceededPolicy) {
    
    /**
     @brief If the limit for long requests is exceeded an exception is thrown.
     <br/> This policy ensures the connection pool is never exhausted by handling the situation as a programmer error (what in fact it is).
     */
    LSLongRequestLimitExceededPolicyThrow= 0,

    /**
     @brief If the limit for long requests is exceeded the request fails with a network error.
     <br/> This policy ensures the connection pool is never exhausted by handling the situation as a runtime error. While a runtime error is
     easier to recover than an exception (especially with Swift), understand that this situation is not something that should be recovered.
     Submitting too many long requests should be avoided by design, not by retrying the requests.
     */
    LSLongRequestLimitExceededPolicyFail,
    
    /**
     @brief If the limit for long requests is exceeded enqueue the requests in excess.
     <br/> The request in excess will be executed when a connection is freed. Note that this policy may lead to connection pool exhaustion 
     if too many long requests are submitted. It should not be used unless you know what you are doing.
     */
    LSLongRequestLimitExceededPolicyEnqueue
};


@class LSURLDispatchOperation;
@protocol LSURLDispatchDelegate;


/**
 @brief LSURLDispatcher is a singleton object providing URL request services with strict concurrency monitoring to avoid connection pool exhaustion.
 <br/> Normal system behavior, on both iOS and macOS, is that, when the connection pool for a specific end-point is exhausted, requests in excess simply timeout.
 The system does not even try to execute them. LSURLDispatcher guarantees to avoid this situation by strictly monitoring how many requests are running. If
 a request in excess is submitted, it may either keep it on hold and submit when a connection is freed, or quickly fail with an exception or runtime error.
 <br/> URL requests submitted to LSURLDispatcher may be of 3 different types: <ul>
 <li> <b>Synchronous requests</b>: keep the calling thread suspended and return only with a complete NSData or NSError;
 <li> <b>Short requests</b>: detaches from the calling thread and works asynchronously with a specified delegate;
 <li> <b>Long requests</b>: detaches from the calling thread and works asynchronously, like short connections, but their number
 is further monitored to avoid connection pool congestion.
 </ul>
 <br/> Given these 3 types of requests, the expected usage pattern is the following: <ul>
 <li> Synchronous and short requests should be used for short request-reply roundtrips that are expected to last for a few seconds.
 <br/> Their concurrency is limited by LSURLDispatcher configuration and, if a request in excess is submitted, they are enqueued until a
 connection is freed.
 <li> Long requests should be used only for long running connections, such as data streaming, audio streaming, VoIPs, videos, etc.
 <br/> Their concurrency is further limited by a specific configuration setting (2 by default on iOS, so to always keep some spare connections for
 short and synchronous requests), and LSURLDispatcher can tell if another long running request can be submitted or not. If it can't and it is
 submitted anyway, LSURLDispatcher reacts according to a specified policy (by default it throws an exception, but other policies are available).
 </ul>
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
#pragma mark Initialization

/**
 @brief Creates an instance of LSURLDispatcher with the a default maximum number of concurrent requests and
 long running requests for the same end-point.
 */
- (nonnull instancetype) init;

/**
 @brief Creates an instance of LSURLDispatcher with the specified maximum number of concurrent requests and
 long running requests for the same end-point.
 <br/> While there is no limit enforced on the passed values, consider that iOS connection pools have a size of 4, while
 macOS connection pools have a size of 6. Passing a value greater than these sizes will render the LSURLDispatcher
 unable to protect against connection pool exhaustion, and your app will incur in unexpected network timeouts.
 <br/> Note that <code>maxLongRunningRequestsPerEndPoint</code> should be intended as a part of <code>maxRequestsPerEndPoint</code>:
 of all the requests concurrently running for a certain end-point, the part intended for long running requests. On iOS typical
 values are 4 and 2: 4 maximum requests, of which maxium 2 are long running requests.
 @param maxRequestsPerEndPoint The maximum number of concurrent requests for the same end-point.
 <br/> The value of this parameter is also passed to the system as the <code>HTTPMaximumConnectionsPerHost</code> of the
 underlying <code>NSURLSession</code> configuration. Note that, despite the name, the system applies the limit <i>per end-point</i>,
 not <i>per host</i>.
 @param maxLongRunningRequestsPerEndPoint The number of concurrent long running requests for the same end-point.
 @throws NSException If <code>maxLongRunningRequestsPerEndPoint</code> is greater than <code>maxRequestsPerEndPoint</code>.
 */
- (nonnull instancetype) initWithMaxRequestsPerEndPoint:(NSUInteger)maxRequestsPerEndPoint
                      maxLongRunningRequestsPerEndPoint:(NSUInteger)maxLongRunningRequestsPerEndPoint NS_DESIGNATED_INITIALIZER;


#pragma mark -
#pragma mark URL request dispatching and checking

/**
 @brief Starts a synchronous request and waits for its completion.
 <br/> If the connection pool is exhausted, the calling thread is put on wait until a connection is freed.
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
 <br/> If the maximum long running request limit is exceeded, depending on the <code>policy</code> parameter it can either: <ul>
 <li>Throw an exception;
 <li>Fail the request;
 <li>Enqueue the request as nothing was wrong.
 </ul>
 @param request The URL request to be submitted.
 <br/> Note: the timeout interval specified on the request is honored and enforced.
 @param delegate The delegate to be called as the connection request progresses in its completion.
 @param policy The policy to apply when the maximum long running request limit is exceeded.
 @return A descriptor of the ongoing URL request operation.
 @throws NSException If the maximum long running request limit is exceeded and the <code>policy</code>
 parameter is <code>LSLongRequestLimitExceededPolicyThrow</code>.
 @throws NSException If request and/or delegate are <code>nil</code>.
 @throws NSException If policy is invalid.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (nonnull LSURLDispatchOperation *) dispatchLongRequest:(nonnull NSURLRequest *)request delegate:(nonnull id <LSURLDispatchDelegate>)delegate policy:(LSLongRequestLimitExceededPolicy)policy;

/**
 @brief Checks if the end-point specified by the request currently has at least a spare connection to be used.
 @param request The URL request to be checked.
 @return <code>YES</code> if the end-point has a spare long running connection.
 @throws NSException If the request is <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (BOOL) isLongRequestAllowed:(nonnull NSURLRequest *)request;

/**
 @brief Checks if the end-point specified by the URL currently has at least a spare connection to be used.
 @param url The URL to be checked.
 @return <code>YES</code> if the end-point has a spare long running connection.
 @throws NSException If the URL is <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (BOOL) isLongRequestAllowedToURL:(nonnull NSURL *)url;

/**
 @brief Checks if the end-point specified currently has at least a spare connection to be used.
 @param host The host of the end-point to be checked.
 @param port The port of the end-point to be checked.
 @return <code>YES</code> if the end-point has a spare long running connection.
 @throws NSException If the host is <code>nil</code>.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (BOOL) isLongRequestAllowedToHost:(nonnull NSString *)host port:(int)port;

/**
 @brief Returns the number of currently long running requests to the specified URL.
 @param url The URL to be checked.
 @return The number of currently running long requests.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (NSUInteger) countOfRunningLongRequestsToURL:(nonnull NSURL *)url;

/**
 @brief Returns the number of currently long running requests to the specified end-point.
 @param host The host of the end-point to be checked.
 @param port The port of the end-point to be checked.
 @return The number of currently running long requests.
 @see maxLongRunningRequestsPerEndPoint.
 */
- (NSUInteger) countOfRunningLongRequestsToHost:(nonnull NSString *)host port:(int)port;


#pragma mark -
#pragma mark Properties

/**
 @brief Configured maximum number of concurrent requests for the same end-point.
 */
@property (nonatomic, readonly) NSUInteger maxRequestsPerEndPoint;

/**
 @brief Configured maximum number of concurrent long running requests for the same end-point.
 <br/> This parameter may be changed at run-time, but must always be lower than or equal to <code>maxRequestsPerEndPoint</code>.
 @throws NSException If trying to set the value greater than <code>maxRequestsPerEndPoint</code>.
 */
@property (nonatomic, assign) NSUInteger maxLongRunningRequestsPerEndPoint;


@end
