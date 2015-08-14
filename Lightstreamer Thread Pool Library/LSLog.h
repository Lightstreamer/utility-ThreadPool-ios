//
//  LSLog.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 13/03/11.
//  Copyright 2011-2015 Weswit srl. All rights reserved.
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

#define LOG_SRC_TIMER              (8)
#define LOG_SRC_URL_DISPATCHER    (16)
#define LOG_SRC_THREAD_POOL       (32)


@protocol LSLogDelegate;


/**
 @brief LSLog provides a simple logging system with separately enabled sources.
 <br/> Log lines are diverted to the system console (NSLog), unless a log delegate is specified.
 @see LSLogDelegate.
 */
@interface LSLog : NSObject


#pragma mark -
#pragma mark Log delegation

/**
 @brief Sets a new log delegate. Once a delegate is set, all subsequent log lines are redirected to the delegate.
 <br/> The local logging system will just provide line formatting, no log messages will be written to the console or
 other destinations if not by delegate's initiative.
 @param delegate The log delegate, or <code>nil</code> to revert to the local logging system.
 @see LSLogDelegate.
 */
+ (void) setDelegate:(nullable id <LSLogDelegate>)delegate;


#pragma mark -
#pragma mark Source log filtering

/**
 @brief Enables logging for a specific source.
 <br/> Logging should be considered of debugging level.
 @param source The identifier of the source. Currently supported values are: <ul>
 <li><code>LOG_SRC_TIMER</code> for LSTimerThread logging;
 <li><code>LOG_SRC_URL_DISPATCHER</code> for LSURLDispatcher logging;
 <li><code>LOG_SRC_THREAD_POOL</code> for LSThreadPool logging;
 </ul>
 */
+ (void) enableSourceType:(int)source;

/**
 @brief Enables logging for all sources.
 <br/> Logging should be considered of debugging level.
 */
+ (void) enableAllSourceTypes;

/**
 @brief Disables logging for a specific source.
 @param source The identifier of the source. Currently supported values are: <ul>
 <li><code>LOG_SRC_TIMER</code> for LSTimerThread logging;
 <li><code>LOG_SRC_URL_DISPATCHER</code> for LSURLDispatcher logging;
 <li><code>LOG_SRC_THREAD_POOL</code> for LSThreadPool logging;
 </ul>
 */
+ (void) disableSourceType:(int)source;

/**
 @brief Disables logging for all sources.
 */
+ (void) disableAllSourceTypes;

/**
 @brief Tells if logging of a specific source is enabled.
 <br/> Logging should be considered of debugging level.
 @param source The identifier of the source. Currently supported values are: <ul>
 <li><code>LOG_SRC_TIMER</code> for LSTimerThread logging;
 <li><code>LOG_SRC_URL_DISPATCHER</code> for LSURLDispatcher logging;
 <li><code>LOG_SRC_THREAD_POOL</code> for LSThreadPool logging;
 </ul>
 */
+ (BOOL) isSourceTypeEnabled:(int)source;


@end
