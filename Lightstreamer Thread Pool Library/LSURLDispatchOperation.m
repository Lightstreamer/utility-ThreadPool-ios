//
//  LSURLDispatchOperation.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright (c) 2012-2013 Weswit srl. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  * Neither the name of Weswit srl nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "LSURLDispatchOperation.h"
#import "LSURLDispatcherThread.h"
#import "LSURLDispatcher.h"
#import "LSInvocation.h"


@interface LSURLDispatchOperation ()


#pragma mark -
#pragma mark Internal threaded start

- (void) threadStart;
- (void) threadCancel;


@end


@implementation LSURLDispatchOperation


#pragma mark -
#pragma mark Initialization

- (id) initWithURLRequest:(NSURLRequest *)request endPoint:(NSString *)endPoint delegate:(id<LSURLDispatchDelegate>)delegate gatherData:(BOOL)gatherData isLong:(BOOL)isLong {
	if ((self = [super init])) {
		
		// Initialization
		_request= [request retain];
		_endPoint= [endPoint retain];
		_delegate= [delegate retain];
		_gathedData= gatherData;
		_isLong= isLong;
		
		_waitForCompletion= [[NSCondition alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[_request release];
	[_endPoint release];
	[_delegate release];

	[_thread release];
	[_connection release];
	[_waitForCompletion release];
	
	[_response release];
	[_error release];
	[_data release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Execution

- (void) start {

	// Get a worker thread
	_thread= [[[LSURLDispatcher sharedDispatcher] preemptThreadForEndPoint:_endPoint] retain];

	if (_gathedData)
		_data= [[NSMutableData alloc] init];

	// Start the connection on the dispatcher thread
	[self performSelector:@selector(threadStart) onThread:_thread withObject:nil waitUntilDone:NO];
}

- (void) waitForCompletion {
	
	// Wait for a signal
	[_waitForCompletion lock];
	[_waitForCompletion wait];
	[_waitForCompletion unlock];
}

- (void) cancel {
	
	// Cancel the connection on the dispatcher thread
	[self performSelector:@selector(threadCancel) onThread:_thread withObject:nil waitUntilDone:NO];
}


#pragma mark -
#pragma mark Methods of NSURLConnectionDelegate

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	
	// Avoid wasting time if the connection has been cancelled
	if (connection != _connection)
		return;
	
	[_response release];
	_response= [response retain];

	// Truncate current data buffer
	[_data setLength:0];
	
	// Call delegate
	[_delegate dispatchOperation:self didReceiveResponse:response];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	
	// Avoid wasting time if the connection has been cancelled
	if (connection != _connection)
		return;
	
	[_data appendData:data];
	
	// Call delegate
	[_delegate dispatchOperation:self didReceiveData:data];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	
	// Avoid wasting time if the connection has been cancelled
	if (connection != _connection)
		return;
	
	_error= [error retain];
	
	// Release the connection
	NSURLConnection *oldConnection= _connection;
	_connection= nil;
	[oldConnection release];

	NSLog(@"LSURLDispatchOperation: connection of operation %p for end-point %@ failed with error %@", self, _endPoint, error);

	// Notify waiting threads
	[_waitForCompletion lock];
	[_waitForCompletion broadcast];
	[_waitForCompletion unlock];
	
	// Notify the dispatcher
	[[LSURLDispatcher sharedDispatcher] operationDidFinish:self];
	
	// Call delegate
	[_delegate dispatchOperation:self didFailWithError:error];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
	
	// Avoid wasting time if the connection has been cancelled
	if (connection != _connection)
		return;
	
	// Release the connection
	NSURLConnection *oldConnection= _connection;
	_connection= nil;
	[oldConnection release];
	
	NSLog(@"LSURLDispatchOperation: connection of operation %p for end-point %@ finished loading", self, _endPoint);

	// Notify waiting threads
	[_waitForCompletion lock];
	[_waitForCompletion broadcast];
	[_waitForCompletion unlock];

	// Notify the dispatcher
	[[LSURLDispatcher sharedDispatcher] operationDidFinish:self];

	// Call delegate
	[_delegate dispatchOperationDidFinish:self];
}


#pragma mark -
#pragma mark Internal threaded start

- (void) threadStart {

	// Get run loop for dispather thread
	NSRunLoop *runLoop= [NSRunLoop currentRunLoop];
	
	NSLog(@"LSURLDispatchOperation: starting connection of operation %p for end-point %@ on thread %p", self, _endPoint, _thread);
	
	// Start connection on dispatcher run loop
	_connection= [[NSURLConnection alloc] initWithRequest:_request delegate:self];
	[_connection scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
	[_connection start];
}

- (void) threadCancel {
	
	// Avoid wasting time if the connection has been cancelled
	if (!_connection)
		return;
	
	// Cancel connection
	NSURLConnection *oldConnection= _connection;
	_connection= nil;
	
	[oldConnection cancel];
	[oldConnection release];
	
	NSLog(@"LSURLDispatchOperation: connection of operation %p for end-point %@ cancelled", self, _endPoint);
	
	// Notify waiting threads
	[_waitForCompletion lock];
	[_waitForCompletion broadcast];
	[_waitForCompletion unlock];
	
	// Notify the dispatcher
	[[LSURLDispatcher sharedDispatcher] operationDidFinish:self];
	
	// Call delegate
	[_delegate dispatchOperationDidFinish:self];
}


#pragma mark -
#pragma mark Properties

@synthesize request= _request;
@synthesize endPoint= _endPoint;
@synthesize isLong= _isLong;

@synthesize thread= _thread;

@synthesize response= _response;
@synthesize error= _error;
@synthesize data= _data;


@end
