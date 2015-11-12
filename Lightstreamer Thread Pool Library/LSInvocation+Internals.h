//
//  LSInvocation+Internals.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 11/08/15.
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

#import "LSInvocation.h"


#pragma mark -
#pragma mark LSInvocation Internals category

@interface LSInvocation (Internals)


#pragma mark -
#pragma mark Initialization (for internal use only)

+ (LSInvocation *) invocationWithBlock:(LSInvocationBlock)block;
+ (LSInvocation *) invocationWithTarget:(id)target;
+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector;
+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector delay:(NSTimeInterval)delay;
+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument;
+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument delay:(NSTimeInterval)delay;

- (instancetype) initWithBlock:(LSInvocationBlock)block;
- (instancetype) initWithTarget:(id)target selector:(SEL)selector argument:(id)argument delay:(NSTimeInterval)delay;


#pragma mark -
#pragma mark Completion monitoring (for internal use only)

- (void) completed;


@end
