//
//  LSInvocation.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 18/09/12.
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

@interface LSInvocation : NSObject {
	id _target;
	SEL _selector;
	id _argument;
	
	NSCondition *_completionMonitor;
	BOOL _completed;
}


#pragma mark -
#pragma mark Initialization

+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector;
+ (LSInvocation *) invocationWithTarget:(id)target selector:(SEL)selector argument:(id)argument;

- (id) initWithTarget:(id)target selector:(SEL)selector argument:(id)argument;


#pragma mark -
#pragma mark Completion monitoring (for custom use)

- (void) waitForCompletion;
- (void) completed;


#pragma mark -
#pragma mark Properties

@property (nonatomic, readonly) id target;
@property (nonatomic, readonly) SEL selector;
@property (nonatomic, readonly) id argument;


@end
