//
//  LSTimerThread.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 28/08/12.
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

@interface LSTimerThread : NSObject {
	NSThread *_thread;
	BOOL _running;
}


#pragma mark -
#pragma mark Singleton management

+ (LSTimerThread *) sharedTimer;
+ (void) dispose;


#pragma mark -
#pragma mark Setting and removing timers

- (void) performSelector:(SEL)aSelector onTarget:(id)aTarget withObject:(id)anArgument afterDelay:(NSTimeInterval)delay;
- (void) performSelector:(SEL)aSelector onTarget:(id)aTarget afterDelay:(NSTimeInterval)delay;

- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument;
- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector;
- (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget;


@end
