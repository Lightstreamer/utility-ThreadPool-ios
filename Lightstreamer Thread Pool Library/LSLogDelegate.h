//
//  LSLogDelegate.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 04/02/15.
//
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


/**
 @brief The LSLogDelegate protocol can be used to redirect the simple logging
 system to a different destination, such as a file or an application-wide
 logging system.
 */
@protocol LSLogDelegate <NSObject>


#pragma mark -
#pragma mark Logging

/**
 @brief Called when a log line has to be appended. The line contains preformatted content,
 such as the current thread pointer, the logging source name and its pointer, and
 the actual log message. The line does not contain any line-endings.
 @param logLine The log line to be appended.
 */
- (void) appendLogLine:(nonnull NSString *)logLine;


@end
