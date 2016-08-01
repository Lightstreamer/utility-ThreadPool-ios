//
//  LSTimerThread.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 28/08/12.
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

#import <Foundation/Foundation.h>

#import "LSInvocation.h"


/**
 @brief LSTimerThread is a singleton object that provides services to perform delayed calls of methods of any target/selector, 
 without requiring a run loop on the main thread.
 <br/> A specific thread is started and shared, with an appropriate run loop, to make the delayed calls.
 */
@interface LSTimerThread : NSObject


#pragma mark -
#pragma mark Singleton management

/**
 @brief Accessor for the LSTimerThread singleton.
 <br/> At the first call the singleton is initialized.
 @return The LSTimerThread singleton.
 */
+ (nonnull LSTimerThread *) sharedTimer;

/**
 @brief Disposes of the current LSTimerThread singleton.
 <br/> If <code>sharedTimer</code> is called again after <code>dispose</code>, a new singleton is initialized.
 */
+ (void) dispose;


#pragma mark -
#pragma mark Setting and removing timers

/**
 @brief Schedules a delayed call of a block.
 @param block The block to be executed.
 @param delay Delay of the call, expressed as seconds.
 @throws NSException If the block is <code>nil</code>.
 */
- (void) performBlock:(nonnull LSInvocationBlock)block afterDelay:(NSTimeInterval)delay;

/**
 @brief Schedules a delayed call of a target and selector with an argument.
 <br/> The selector (method signature) must have exactly one argument.
 @param selector Selector (method signature) to be called.
 @param target Target (object) to be called.
 @param argument Single argument (parameter) of the selector. A <code>nil</code> is accepted.
 @param delay Delay of the call, expressed as seconds.
 @throws NSException If the target or selector are <code>nil</code>.
 */
- (void) performSelector:(nonnull SEL)selector onTarget:(nonnull id)target withObject:(nullable id)argument afterDelay:(NSTimeInterval)delay;

/**
 @brief Schedules a delayed call of a target and selector with an argument.
 <br/> The selector (method signature) must have no arguments.
 @param selector Selector (method signature) to be called.
 @param target Target (object) to be called.
 @param delay Delay of the call, expressed as seconds.
 @throws NSException If the target or selector are <code>nil</code>.
 */
- (void) performSelector:(nonnull SEL)selector onTarget:(nonnull id)target afterDelay:(NSTimeInterval)delay;

/**
 @brief Cancels a previously scheduled call to the specified target and selector and with the specified argument.
 <br/> The selector (method signature) must have exactly one argument. If the argument differs (it is checked for
 equality with <code>isEqual:</code>) the scheduled call will not be canceled.
 @param target Target (object) previously scheduled for a call.
 @param selector Selector (method signature) previously scheduled for a call.
 @param argument Single argument (parameter) of the selector previously scheduled for a call. A <code>nil</code> is accepted.
 @throws NSException If the target or selector are <code>nil</code>.
 */
- (void) cancelPreviousPerformRequestsWithTarget:(nonnull id)target selector:(nonnull SEL)selector object:(nullable id)argument;

/**
 @brief Cancels a previously scheduled call to the specified target and selector with no arguments.
 <br/> The selector (method signature) must have no arguments. The scheduled call must not have specified
 an argument, or it will not be canceled.
 @param target Target (object) previously scheduled for a call.
 @param selector Selector (method signature) previously scheduled for a call.
 @throws NSException If the target or selector are <code>nil</code>.
 */
- (void) cancelPreviousPerformRequestsWithTarget:(nonnull id)target selector:(nonnull SEL)selector;

/**
 @brief Cancels any previously scheduled call to the specified target.
 <br/> Any scheduled call for the target, whatever the selector or the argument specified, will be canceled.
 @param target Target (object) previously scheduled for a call.
 @throws NSException If the target is <code>nil</code>.
 */
- (void) cancelPreviousPerformRequestsWithTarget:(nonnull id)target;


@end
