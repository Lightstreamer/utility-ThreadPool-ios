//
//  LSInvocation.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 18/09/12.
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


/**
 @brief Type used to characterize blocks that can be schedule for call with LSThreadPool.
 */
typedef void (^LSInvocationBlock)(void);


/**
 @brief LSInvocation describes a scheduled call, such as the target and selector, block or delay.
 <br/> Provides a service to wait for its completion.
 */
@interface LSInvocation : NSObject


#pragma mark -
#pragma mark Completion monitoring

/**
 @brief Waits for the scheduled call to complete.
 <br/> Puts the calling thread to wait until the scheduled call execution has been completed.
 */
- (void) waitForCompletion;


#pragma mark -
#pragma mark Properties

/**
 @brief The block that must be called with this scheduled call.
 <br/> May be nil if the scheduled call has been initialized with a target and selector.
 */
@property (nonatomic, readonly) LSInvocationBlock block;

/**
 @brief The target that must be called with this scheduled call.
 <br/> May be nil if the scheduled call has been initialized with a block.
 */
@property (nonatomic, readonly) id target;

/**
 @brief The selector of the target to be called with this scheduled call.
 <br/> May be nil.
 */
@property (nonatomic, readonly) SEL selector;

/**
 @brief The argument of the selector to be called with this scheduled call.
 <br/> May be nil.
 */
@property (nonatomic, readonly) id argument;

/**
 @brief The delay to be waited for before executing the scheduled call.
 <br/> NOTE: used internally by the LSTimerThread.
 */
@property (nonatomic, readonly) NSTimeInterval delay;


@end
