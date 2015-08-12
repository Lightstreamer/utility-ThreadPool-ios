//
//  LSURLDispatchOperation+Internals.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 11/08/15.
//  Copyright (c) 2015 Weswit srl. All rights reserved.
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


#pragma mark -
#pragma mark LSURLDispatchOperation Internals category

@interface LSURLDispatchOperation (Internals)


#pragma mark -
#pragma mark Initialization (for internal use only)

- (id) initWithURLRequest:(NSURLRequest *)request endPoint:(NSString *)endPoint delegate:(id <LSURLDispatchDelegate>)delegate gatherData:(BOOL)gatherData isLong:(BOOL)isLong;


#pragma mark -
#pragma mark Execution (for internal use only)

- (void) start;
- (void) startAndWaitForCompletion;


#pragma mark -
#pragma mark Access to underlying thread (for internal use only)

- (LSURLDispatcherThread *) thread;


@end

