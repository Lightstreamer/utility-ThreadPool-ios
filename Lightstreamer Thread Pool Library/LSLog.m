//
//  LSLog.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 13/03/11.
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

#import "LSLog.h"
#import "LSLogDelegate.h"

#define LOG_SRC_TIMER_NAME           (@"LSTimerThread")
#define LOG_SRC_URL_DISPATCHER_NAME  (@"LSURLDispatcher")
#define LOG_SRC_THREAD_POOL_NAME     (@"LSThreadPool")


#pragma mark -
#pragma mark LSLog statics

static int __enabledSourceTypes= 0;
static id <LSLogDelegate> __delegate= nil;


#pragma mark -
#pragma mark LSLog implementation

@implementation LSLog


#pragma mark -
#pragma mark Logging

+ (void) sourceType:(int)sourceType source:(id)source log:(NSString *)format, ... {
    if (__enabledSourceTypes & sourceType) {
        @synchronized ([LSLog class]) {

            // Thread name
            NSThread *thread= [NSThread currentThread];
            NSString *threadName= (thread.name.length > 0) ? thread.name : [NSString stringWithFormat:@"Thread %p", thread];
            
            @try {
                
                // Source name
                NSString *sourceName= nil;
                switch (sourceType) {
                    case LOG_SRC_TIMER: sourceName= LOG_SRC_TIMER_NAME; break;
                    case LOG_SRC_URL_DISPATCHER: sourceName= LOG_SRC_URL_DISPATCHER_NAME; break;
                    case LOG_SRC_THREAD_POOL: sourceName= LOG_SRC_THREAD_POOL_NAME; break;
                }

                // Variable arguments formatting
                va_list arguments;
                va_start(arguments, format);
                NSString *logMessage= [[NSString alloc] initWithFormat:format arguments:arguments];
                va_end(arguments);
                
                // Logging
                NSString *logLine= [NSString stringWithFormat:@"<%@> %@ %p: %@", threadName, sourceName, source, logMessage];
                if (__delegate)
                    [__delegate appendLogLine:logLine];
                else
                    NSLog(@"%@", logLine);

            } @catch (NSException *e) {
                NSLog(@"<%@> Exception caught while logging with format '%@': %@, reason: '%@', user info: %@", threadName, format, e.name, e.reason, e.userInfo);
            }
        }
    }
}

+ (void) log:(NSString *)format, ... {
    @synchronized ([LSLog class]) {
        
        // Thread name
        NSThread *thread= [NSThread currentThread];
        NSString *threadName= (thread.name.length > 0) ? thread.name : [NSString stringWithFormat:@"Thread %p", thread];

        @try {
        
            // Variable arguments formatting
            va_list arguments;
            va_start(arguments, format);
            NSString *logMessage= [[NSString alloc] initWithFormat:format arguments:arguments];
            va_end(arguments);
            
            // Logging
            NSString *logLine= [NSString stringWithFormat:@"<%@> %@", threadName, logMessage];
            if (__delegate)
                [__delegate appendLogLine:logLine];
            else
                NSLog(@"%@", logLine);

        } @catch (NSException *e) {
            NSLog(@"<%@> Exception caught while logging with format '%@': %@, reason: '%@', user info: %@", threadName, format, e.name, e.reason, e.userInfo);
        }
    }
}


#pragma mark -
#pragma mark Log delegation

+ (void) setDelegate:(id <LSLogDelegate>)delegate {
    @synchronized ([LSLog class]) {
        __delegate= delegate;
    }
}


#pragma mark -
#pragma mark Source log filtering

+ (void) enableSourceType:(int)source {
    __enabledSourceTypes= (__enabledSourceTypes | source);
}

+ (void) enableAllSourceTypes {
    __enabledSourceTypes= 0xffffffff;
}

+ (void) disableSourceType:(int)source {
    __enabledSourceTypes= (__enabledSourceTypes & (~source));
}

+ (void) disableAllSourceTypes {
    __enabledSourceTypes= 0;
}

+ (BOOL) isSourceTypeEnabled:(int)source {
    return (__enabledSourceTypes & source);
}


@end
