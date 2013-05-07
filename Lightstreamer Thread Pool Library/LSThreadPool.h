//
//  LSThreadPool.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 17/09/12.
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


@class LSInvocation;

@interface LSThreadPool : NSObject {
	NSString *_name;
	int _size;

	NSMutableArray *_threads;

	NSMutableArray *_invocationQueue;
	NSCondition *_monitor;
	
    int _nextThreadId;
	BOOL _disposed;
}


#pragma mark -
#pragma mark Initialization

+ (LSThreadPool *) poolWithName:(NSString *)name size:(int)poolSize;
- (id) initWithName:(NSString *)name size:(int)poolSize;

- (void) dispose;


#pragma mark -
#pragma mark Invocation scheduling

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector;
- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector withObject:(id)object;


#pragma mark -
#pragma mark Properties

@property (nonatomic, readonly) int queueSize;


@end
