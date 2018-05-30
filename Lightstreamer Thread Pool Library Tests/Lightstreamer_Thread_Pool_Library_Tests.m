//
//  Lightstreamer_Thread_Pool_Library_Tests.m
//  Lightstreamer Thread Pool Library Tests
//
//  Created by Gianluca Bertani on 09/01/13.
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

#import <XCTest/XCTest.h>

#import "LSThreadPoolLib.h"

#define THREAD_POOL_TEST_COUNT                              (100)
#define THREAD_POOL_TEST_MAX_COUNT_DELAY_MSECS              (200)
#define THREAD_POOL_TEST_SEMAPHORE_NOTIFY_DELAY_MSECS      (1000)

#define TIMER_TEST_COUNT                                     (20)
#define TIMER_TEST_INITIAL_DELAY                              (0.6)
#define TIMER_TEST_INCREMENTAL_DELAY_MIN                      (0.3)
#define TIMER_TEST_INCREMENTAL_DELAY_MAX                      (0.9)

#define URL_DISPATCHER_TEST_URL                              (@"http://support.apple.com/downloads/DL1581/en_US/OSXUpdCombo10.8.2.dmg")
#define URL_DISPATCHER_TEST_COUNT                            (20)
#define URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES            (10000)
#define URL_DISPATCHER_TEST_TIMEOUT                          (10.0)


#pragma mark -
#pragma mark Lightstreamer_Thread_Pool_Library_Tests declaration

@interface Lightstreamer_Thread_Pool_Library_Tests : XCTestCase <LSURLDispatchDelegate> {
    LSThreadPool *_threadPool;
    
    NSUInteger _count;
    NSUInteger _failedCount;
    NSCondition *_semaphore;
    
    NSDate *_timerBegin;
    NSMutableDictionary<NSNumber *, NSNumber *> *_timerInvocations;
    
    NSMutableDictionary<NSString *, NSMutableData *> *_downloads;
}


#pragma mark -
#pragma mark Callback for timer test

- (void) saveInvocationTime:(NSNumber *)number;


@end


#pragma mark -
#pragma mark Lightstreamer_Thread_Pool_Library_Tests implementation

@implementation Lightstreamer_Thread_Pool_Library_Tests


#pragma mark -
#pragma mark Set up and tear down

- (void) setUp {
    [super setUp];
    
    // Create thread pool
    _threadPool= [[LSThreadPool alloc] initWithName:@"Test" size:4];
}

- (void) tearDown {
    
    // Dispose and release thread pool
    [_threadPool dispose];
    _threadPool= nil;
    
    // Dispose the URL dispatcher
    [LSURLDispatcher dispose];
    
    [super tearDown];
}


#pragma mark -
#pragma mark Tests

/**
 @brief This test will run 101 concurrent invocations. The first 100 will add 1 to a counter, the last one will unlock a semaphore.
 <br/> You can monitor the pool size and thread execution on the console.
 */
- (void) testThreadPool {
    [LSLog disableAllSourceTypes];
    [LSLog enableSourceType:LOG_SRC_THREAD_POOL];
    
    _count= 0;

    _semaphore= [[NSCondition alloc] init];
    [_semaphore lock];
    
    for (int i= 0; i < THREAD_POOL_TEST_COUNT; i++) {
        [_threadPool scheduleInvocationForBlock:^{
            
            // Sleep up to 1.0 secs
            int random= 0;
            int result= SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
            if (result != 0)
                NSLog(@"%@: could net get a random number", [NSThread currentThread].name);
            
            NSTimeInterval delay= ((double) (ABS(random) % THREAD_POOL_TEST_MAX_COUNT_DELAY_MSECS)) / 1000.0;
            
            [NSThread sleepForTimeInterval:delay];
            
            // Update count
            NSUInteger count= 0;
            @synchronized (self) {
                self->_count++;
                
                count= self->_count;
            }
            
            NSLog(@"%@: count: %lu", [NSThread currentThread].name, (unsigned long) count);
        }];
    }
    
    [_threadPool scheduleInvocationForBlock:^{

        // Sleep 2.0 secs
        [NSThread sleepForTimeInterval:THREAD_POOL_TEST_SEMAPHORE_NOTIFY_DELAY_MSECS / 1000.0];
        
        // Notifiy end of count
        [self->_semaphore lock];
        [self->_semaphore signal];
        [self->_semaphore unlock];
    }];
    
    NSLog(@"TestThreadPool: invocations scheduled, waiting...");
    
    [_semaphore wait];
    [_semaphore unlock];

    _semaphore= nil;

    XCTAssertTrue(_count == THREAD_POOL_TEST_COUNT, @"Not all invocations have been performed (count: %lu)", (unsigned long) _count);
}

#if !TARGET_OS_SIMULATOR

/**
 @brief This test will schedule different calls at random intervals and check they are actually executed when expected.
 <br/> NOTE: It is skipped on iOS and tvOS since they seem to have timers with much worse resolution than macOS (even in the simulator).
 */
- (void) testTimer {
    [LSLog disableAllSourceTypes];
    [LSLog enableSourceType:LOG_SRC_TIMER];
    
    // Instantiate the timer and wait for the thread to start
    [LSTimerThread sharedTimer];
    [NSThread sleepForTimeInterval:0.1];
    
    _timerBegin= [NSDate date];
    _timerInvocations= [NSMutableDictionary dictionary];
    
    NSTimeInterval delay= TIMER_TEST_INITIAL_DELAY;
    NSMutableArray<NSNumber *> *expectedDelays= [NSMutableArray array];
    
    NSLog(@"Scheduling %d delayed invocations...", TIMER_TEST_COUNT);
    
    for (int i= 0; i < TIMER_TEST_COUNT; i++) {
        [expectedDelays addObject:@([[NSDate date] timeIntervalSinceDate:_timerBegin] + delay)];
        
        switch (i % 2) {
            case 0: {
                [[LSTimerThread sharedTimer] performBlock:^{

                    [self saveInvocationTime:@(i)];
                
                } afterDelay:delay];
                break;
            }
                
            case 1: {
                [[LSTimerThread sharedTimer] performSelector:@selector(saveInvocationTime:)
                                                    onTarget:self
                                                  withObject:@(i)
                                                  afterDelay:delay];
                break;
            }
        }
        
        int random= 0;
        int result= SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
        if (result == 0)
            delay += TIMER_TEST_INCREMENTAL_DELAY_MIN + ((double) (ABS(random) % (int)((TIMER_TEST_INCREMENTAL_DELAY_MAX - TIMER_TEST_INCREMENTAL_DELAY_MIN) * 1000.0))) / 1000.0;
        else
            delay += (TIMER_TEST_INCREMENTAL_DELAY_MIN + TIMER_TEST_INCREMENTAL_DELAY_MAX) / 2.0;
    }
    
    // Get the last expected delay and wait for it
    NSNumber *lastExpectedDelay= expectedDelays.lastObject;
    NSTimeInterval wait= lastExpectedDelay.doubleValue + TIMER_TEST_INCREMENTAL_DELAY_MIN;
    
    NSLog(@"Scheduled %d delayed invocations, waiting %.1f secs...", TIMER_TEST_COUNT, wait);
    
    [NSThread sleepForTimeInterval:wait];
    
    for (int i= 0; i < TIMER_TEST_COUNT; i++) {
        NSNumber *expectedDelay= expectedDelays[i];
        NSNumber *actualDelay= _timerInvocations[@(i)];
        
        XCTAssertEqualWithAccuracy([expectedDelay doubleValue], [actualDelay doubleValue], 0.05);
    }
}

#endif // !TARGET_OS_SIMULATOR

/**
 @brief This test will run many concurrent downloads of the same file. Each download will terminate after 10 KB has been received.
 <br/> You can monitor the pool size and thread execution on the console. Short requests are used to download the data. Consider
 that some of the requests may genuinely timeout due to network conditions, these requests are not counted to check if the test
 succeeded.
 */
- (void) testURLDispatcher {
    [LSLog disableAllSourceTypes];
    [LSLog enableSourceType:LOG_SRC_URL_DISPATCHER];
    
    _count= 0;
    _failedCount= 0;
    
    _downloads= [[NSMutableDictionary alloc] init];
    
    _semaphore= [[NSCondition alloc] init];
    [_semaphore lock];
    
    // Use a download long enough
    NSURL *url= [NSURL URLWithString:URL_DISPATCHER_TEST_URL];
    NSMutableURLRequest *req= [NSMutableURLRequest requestWithURL:url];
    [req setTimeoutInterval:URL_DISPATCHER_TEST_TIMEOUT];
    
    for (int i= 0; i < URL_DISPATCHER_TEST_COUNT; i++)
        [[LSURLDispatcher sharedDispatcher] dispatchShortRequest:req delegate:self];
    
    NSLog(@"TestThreadPool: operations dispatched, waiting...");
    
    [_semaphore wait];
    [_semaphore unlock];
    
    _semaphore= nil;
    
    NSUInteger sum= 0;
    for (NSMutableData *download in _downloads.allValues)
        sum += download.length;
    
    XCTAssertTrue(sum > _count * URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES, @"Downloads total does not sum up to required mininum (sum: %lu, minimum: %lu)", (unsigned long) sum, (unsigned long) _count * URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES);
}

#pragma mark -
#pragma mark Callback for timer test

- (void) saveInvocationTime:(NSNumber *)number {
    _timerInvocations[number]= @([[NSDate date] timeIntervalSinceDate:_timerBegin]);
}


#pragma mark -
#pragma mark Methods of LSURLDispatchDelegate

- (void) dispatchOperation:(LSURLDispatchOperation *)operation willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
}

- (void) dispatchOperation:(LSURLDispatchOperation *)operation didReceiveResponse:(NSURLResponse *)response {}

- (void) dispatchOperation:(LSURLDispatchOperation *)operation didReceiveData:(NSData *)data {
    
    // Get a key for the operation
    NSString *opKey= [NSString stringWithFormat:@"%p", operation];
    BOOL finished= NO;

    NSUInteger downloaded= 0;
    @synchronized (self) {
        
        // Get current download for this operation
        NSMutableData *download= _downloads[opKey];
        if (!download) {
            download= [[NSMutableData alloc] init];

            _downloads[opKey]= download;
        }
        
        // Append data if we haven't reached the limit
        if (download.length < URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES) {
            [download appendData:data];

            downloaded= download.length;
            
            // If we have reached the limit count the operation as finished
            if (downloaded >= URL_DISPATCHER_TEST_MAX_DOWNLOAD_BYTES) {
                [operation cancel];
                _count++;
            }
        }
    
        if (_failedCount + _count == URL_DISPATCHER_TEST_COUNT)
            finished= YES;
    }
    
    if (downloaded)
        NSLog(@"Operation %p: downloaded: %lu bytes (count: %lu, failed count: %lu)", operation, (unsigned long) downloaded, (unsigned long) _count, (unsigned long) _failedCount);

    if (finished) {
        
        // Notifiy end of downloads
        [_semaphore lock];
        [_semaphore signal];
        [_semaphore unlock];
    }
}

- (void) dispatchOperation:(LSURLDispatchOperation *)operation didFailWithError:(NSError *)error {
    NSLog(@"Operation %p: download failed with error: %@ (count: %lu, failed count: %lu)", operation, error, (unsigned long) _count, (unsigned long) _failedCount);

    BOOL finished= NO;
    
    @synchronized (self) {
        _failedCount++;
        
        if (_failedCount + _count == URL_DISPATCHER_TEST_COUNT)
            finished= YES;
    }
    
    if (finished) {
        
        // Notifiy end of downloads
        [_semaphore lock];
        [_semaphore signal];
        [_semaphore unlock];
    }
}

- (void) dispatchOperationDidFinish:(LSURLDispatchOperation *)operation {}


@end
