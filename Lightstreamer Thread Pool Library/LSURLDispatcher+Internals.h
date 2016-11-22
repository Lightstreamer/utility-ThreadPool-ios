//
//  LSURLDispatcher+Internals.h
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

#import "LSURLDispatcher.h"


#pragma mark -
#pragma mark LSURLDispatcher Internals category

@interface LSURLDispatcher (Internals)


#pragma mark -
#pragma mark Finalization (for internal use only)

- (void) dispose;


#pragma mark -
#pragma mark Operation synchronization (for internal use only)

- (void) connectionDidFreeForEndPoint:(NSString *)endPoint;


#pragma mark -
#pragma mark Operation notifications (for internal use only)

- (void) operation:(LSURLDispatchOperation *)dispatchOp didStartWithTask:(NSURLSessionDataTask *)task;
- (void) operation:(LSURLDispatchOperation *)dispatchOp didFinishWithTask:(NSURLSessionDataTask *)task;


@end
