//
//  LSThreadPool.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 17/09/12.
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
 @brief LSThreadPool provides a fixed-size thread pool for use in concurrent operations/algorithms.
 <br/> Threads are created on-demand and recycled up to 10 seconds after a call has been scheduled.
 Every 15 seconds a collector passes and disposes of threads on idle since more than 10 seconds.
 */
@interface LSThreadPool : NSObject


#pragma mark -
#pragma mark Initialization

/**
 @brief Creates an LSThreadPool with the specified name and size.
 @param name The name of the thread pool. Used during logging to diagnose problems.
 @param poolSize The maximum size of the thread pool. Threads are created on-demand,
 hence in any moment there may be up to <code>poolSize</code> threads.
 @return The created thread pool.
 @throws NSException If the name is <code>nil</code> or the pool size is 0.
 */
+ (nonnull LSThreadPool *) poolWithName:(nonnull NSString *)name size:(NSUInteger)poolSize;

/**
 @brief Initializes an LSThreadPool with the specified name and size.
 @param name The name of the thread pool, used when logging to diagnose problems.
 @param poolSize The maximum size of the thread pool. Threads are created on-demand,
 hence in any moment there may be up to <code>poolSize</code> threads.
 @throws NSException If the name is <code>nil</code> or the pool size is 0.
 */
- (nonnull instancetype) initWithName:(nonnull NSString *)name size:(NSUInteger)poolSize NS_DESIGNATED_INITIALIZER;

/**
 @brief Invalid initializer, use <code>initWithName:size:</code>.
 @throws NSException Always.
 */
- (nonnull instancetype) init NS_UNAVAILABLE;

/**
 @brief Disposes of any active thread and makes the thread pool no more usable.
 <br/> After a call to <code>dispose</code> no more scheduled calls will be accepted.
 */
- (void) dispose;


#pragma mark -
#pragma mark Invocation scheduling

/**
 @brief Schedules a call to the specified block.
 <br/> If the current size of the thread pool is less than <code>poolSize</code>, a new thread is
 created and the call is executed immediately. Otherwise the call is stored in the queue and will
 be executed on a first-in-first-served basis.
 @param block The block to be executed.
 @return A descriptor of the scheduled call.
 <br/> May be used to wait for its completion.
 @throws NSException If the block is <code>nil</code>.
 @throws NSException If the thread pool has already been disposed of.
 */
- (nonnull LSInvocation *) scheduleInvocationForBlock:(nonnull LSInvocationBlock)block;

/**
 @brief Schedules a call to the specified target and selector.
 <br/> The selector (method signature) must have no arguments.
 <br/> If the current size of the thread pool is less than <code>poolSize</code>, a new thread is
 created and the call is executed immediately. Otherwise the call is stored in the queue and will
 be executed on a first-in-first-served basis.
 @param target The target of the call.
 @param selector The selector of the target to be called.
 @return A descriptor of the scheduled call.
 <br/> May be used to wait for its completion.
 @throws NSException If the target or selector are <code>nil</code>.
 @throws NSException If the thread pool has already been disposed of.
 */
- (nonnull LSInvocation *) scheduleInvocationForTarget:(nonnull id)target selector:(nonnull SEL)selector;

/**
 @brief Schedules a call to the specified target and selector with the specified argument.
 <br/> The selector (method signature) must have exactly one argument.
 <br/> If the current size of the thread pool is less than <code>poolSize</code>, a new thread is
 created and the call is executed immediately. Otherwise the call is stored in the queue and will
 be executed on a first-in-first-served basis.
 @param target The target of the call.
 @param selector The selector of the target to be called.
 @param object The argument of the selector to be called. A <code>nil</code> is accepted.
 @return A descriptor of the scheduled call.
 <br/> May be used to wait for its completion.
 @throws NSException If the target or selector are <code>nil</code>.
 @throws NSException If the thread pool has already been disposed of.
 */
- (nonnull LSInvocation *) scheduleInvocationForTarget:(nonnull id)target selector:(nonnull SEL)selector withObject:(nullable id)object;


#pragma mark -
#pragma mark Properties

/**
 @brief The current size of the scheduled calls queue.
 */
@property (nonatomic, readonly) NSUInteger queueSize;


@end
