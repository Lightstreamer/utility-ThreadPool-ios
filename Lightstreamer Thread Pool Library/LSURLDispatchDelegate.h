//
//  LSURLDispatchDelegate.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright 2013-2015 Weswit Srl
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


/**
 @brief LSURLDispatchDelegate is the protocol any delegate of an LSURLDispatchOperation should implement.
 <br/> Provides forwarding of common NSURLConnectionDelegate and NSURLConnectionDataDelegate events, such as
 <code>connection:didReceiveResponse:</code> and <code>connection:didFailWithError:</code>.
 @see LSURLDispatcher.
 @see LSURLDispatchOperation.
 @see NSURLConnectionDelegate.
 @see NSURLConnectionDataDelegate.
 */
@protocol LSURLDispatchDelegate <NSObject>


/**
 @brief Forwards the <code>connection:didReceiveResponse:</code> event of NSURLConnectionDataDelegate.
 <br/> The event signals that the server did respond and reports its response.
 <br/> As with the original event of NSURLConnectionDataDelegate, this event may be called more than once. 
 The correct behavior in this case is to empty the buffer collecting the received data.
 @param operation The ongoing URL request operation.
 @param response The URL response sent by the server.
 @see LSURLDispatcher.
 @see LSURLDispatchOperation.
 @see NSURLConnectionDataDelegate.
*/
- (void) dispatchOperation:(nonnull LSURLDispatchOperation *)operation didReceiveResponse:(nonnull NSURLResponse *)response;

/**
 @brief Forwards the <code>connection:didReceiveData:</code> event of NSURLConnectionDataDelegate.
 <br/> The event signals that the server did send a block of data as part of the body of its response.
 <br/> As with the original event of NSURLConnectionDataDelegate, this event is usually called than once. 
 The correct behavior in to append the received data in a buffer. Only a <code>dispatchOperationDidFinish:</code>
 signals that no more data will be received.
 @param operation The ongoing URL request operation.
 @param data The data sent by the server.
 @see LSURLDispatcher.
 @see LSURLDispatchOperation.
 @see NSURLConnectionDataDelegate.
 */
- (void) dispatchOperation:(nonnull LSURLDispatchOperation *)operation didReceiveData:(nonnull NSData *)data;

/**
 @brief Forwards the <code>connection:didFailWithError:</code> event of NSURLConnectionDelegate.
 <br/> The event signals that the connection did fail due to an error condition and reports the error.
 @param operation The failed URL request operation.
 @param error The error that caused the connection to fail.
 @see LSURLDispatcher.
 @see LSURLDispatchOperation.
 @see NSURLConnectionDelegate.
 */
- (void) dispatchOperation:(nonnull LSURLDispatchOperation *)operation didFailWithError:(nonnull NSError *)error;

/**
 @brief Forwards the <code>connectionDidFinishLoading:</code> event of NSURLConnectionDataDelegate.
 <br/> The event signals that the connection did finish with no errors.
 @param operation The finished URL request operation.
 @see LSURLDispatcher.
 @see LSURLDispatchOperation.
 @see NSURLConnectionDataDelegate.
 */
- (void) dispatchOperationDidFinish:(nonnull LSURLDispatchOperation *)operation;


@optional

/**
 @brief Forwards the <code>connection:willSendRequestForAuthenticationChallenge:</code> event of NSURLConnectionDelegate.
 <br/> The event signals that the connection needs authentication and reports the challege.
 If this method is not implemented, the request operation will proceed by calling:
 <br/> <code>[challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge]</code>
 @param operation The ongoing URL request operation.
 @param challenge The challege to be used for authentication.
 @see LSURLDispatcher.
 @see LSURLDispatchOperation.
 @see NSURLConnectionDelegate.
 */
- (void) dispatchOperation:(nonnull LSURLDispatchOperation *)operation willSendRequestForAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge;


@end
