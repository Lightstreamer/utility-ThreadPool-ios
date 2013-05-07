//
//  Lightstreamer_Thread_Pool_Library_Tests.m
//  Lightstreamer Thread Pool Library Tests
//
//  Created by Gianluca Bertani on 09/01/13.
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

#import "Lightstreamer_Thread_Pool_Library_Tests.h"
#import "LSThreadPool.h"
#import "LSURLDispatcher.h"
#import "LSURLDispatchOperation.h"

#define THREAD_POOL_TEST_COUNT                              (100)
#define THREAD_POOL_TEST_MAX_COUNT_DELAY_MSECS             (1000)
#define THREAD_POOL_TEST_SEMAPHORE_NOTIFY_DELAY_MSECS      (2000)

#define URL_DISPATCHER_TEST_COUNT                           (100)
#define URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES            (10000)


@interface Lightstreamer_Thread_Pool_Library_Tests ()


#pragma mark -
#pragma mark Internal methods for thread pool test

- (void) addOne;
- (void) semaphoreGreen;


@end


@implementation Lightstreamer_Thread_Pool_Library_Tests

- (void) setUp {
    [super setUp];
	
	// Create thread pool
	_threadPool= [[LSThreadPool alloc] initWithName:@"Test" size:4];
}

- (void) tearDown {
	
	// Dispose and release thread pool
	[_threadPool dispose];
	[_threadPool release];
	
	// Dispose the URL dispatcher
	[LSURLDispatcher dispose];

    [super tearDown];
}

/*
 * This test will run 101 concurrent invocations. The first 100 will add 1
 * to a counter, the last one will unlock a semaphore. You can monitor the
 * pool size and thread execution on the console.
 */
- (void) testThreadPool {
	_count= 0;
	
	_semaphore= [[NSCondition alloc] init];
	[_semaphore lock];
	
	for (int i= 0; i < THREAD_POOL_TEST_COUNT; i++)
		[_threadPool scheduleInvocationForTarget:self selector:@selector(addOne)];
	
	[_threadPool scheduleInvocationForTarget:self selector:@selector(semaphoreGreen)];
	
	[_semaphore wait];
	[_semaphore unlock];

	[_semaphore release];
	_semaphore= nil;

	STAssertTrue(_count == THREAD_POOL_TEST_COUNT, @"Not all invocations have been performed (count: %d)", _count);
}

/*
 * This test will run 100 concurrent downloads of the same file. Each download will
 * terminate after 10 KB has been received. You can monitor the pool size and thread
 * execution on the console. We use short operations because long operations would
 * raise an exception as soon as the limit is reached (so that you can handle the 
 * condition).
 */ 
- (void) testURLDispatcher {
	_count= 0;
	_downloads= [[NSMutableDictionary alloc] init];
	
	_semaphore= [[NSCondition alloc] init];
	[_semaphore lock];

	// Use Apple's OS X 10.8.2 Combo Update, which is long enough
	NSURL *url= [NSURL URLWithString:@"http://support.apple.com/downloads/DL1581/en_US/OSXUpdCombo10.8.2.dmg"];
	NSURLRequest *req= [NSURLRequest requestWithURL:url];

	for (int i= 0; i < URL_DISPATCHER_TEST_COUNT; i++) {
		LSURLDispatchOperation *op= [[LSURLDispatcher sharedDispatcher] dispatchShortRequest:req delegate:self];

		// Start the operation (it will wait if too many operations are already running)
		[op start];
	}
	
	[_semaphore wait];
	[_semaphore unlock];
	
	[_semaphore release];
	_semaphore= nil;
	
	int sum= 0;
	for (NSMutableData *download in [_downloads allValues])
		sum += [download length];
	
	STAssertTrue(sum > URL_DISPATCHER_TEST_COUNT * URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES, @"Downloads total does not sum up to required mininum (sum: %d)", sum);
}


#pragma mark -
#pragma mark Internal methods for thread pool test

- (void) addOne {

	// Sleep up to 1.0 secs
	int random= 0;
	SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
	NSTimeInterval delay= ((double) (ABS(random) % THREAD_POOL_TEST_MAX_COUNT_DELAY_MSECS)) / 1000.0;
	
	[NSThread sleepForTimeInterval:delay];

	// Update count
	int count= 0;
	@synchronized (self) {
		_count++;
		
		count= _count;
	}
	
	NSLog(@"Thread %p: count: %d", [NSThread currentThread], count);
}

- (void) semaphoreGreen {
	
	// Sleep 2.0 secs
	[NSThread sleepForTimeInterval:THREAD_POOL_TEST_SEMAPHORE_NOTIFY_DELAY_MSECS / 1000.0];

	// Notifiy end of count
	[_semaphore lock];
	[_semaphore signal];
	[_semaphore unlock];
}


#pragma mark -
#pragma mark Methods of LSURLDispatchDelegate

- (void) dispatchOperation:(LSURLDispatchOperation *)operation didReceiveResponse:(NSURLResponse *)response {}

- (void) dispatchOperation:(LSURLDispatchOperation *)operation didReceiveData:(NSData *)data {
	
	// Get a key for the operation
	NSString *opKey= [NSString stringWithFormat:@"%p", operation];
	BOOL finished= NO;

	int downloaded= 0;
	@synchronized (self) {
		
		// Get current download for this operation
		NSMutableData *download= [_downloads objectForKey:opKey];
		if (!download) {
			download= [[[NSMutableData alloc] init] autorelease];

			[_downloads setObject:download forKey:opKey];
		}
		
		// Append data if we haven't reached the limit
		if ([download length] < URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES) {
			[download appendData:data];

			downloaded= [download length];
			
			// If we have reached the limit count the operation as finished
			if (downloaded >= URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES) {
				[operation cancel];
				_count++;
			}
		}
		
		if (_count == URL_DISPATCHER_TEST_COUNT)
			finished= YES;
	}
	
	NSLog(@"Operation %p: dowloaded: %d bytes", [NSThread currentThread], downloaded);

	if (finished) {
		
		// Notifiy end of downloads
		[_semaphore lock];
		[_semaphore signal];
		[_semaphore unlock];
	}
}

- (void) dispatchOperation:(LSURLDispatchOperation *)operation didFailWithError:(NSError *)error {
	STFail(@"Download failed with error: %@ (user info: %@)", error, [error userInfo]);
}

- (void) dispatchOperationDidFinish:(LSURLDispatchOperation *)operation {}


@end
