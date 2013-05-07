//
//  Lightstreamer_Thread_Pool_Library_Tests.h
//  Lightstreamer Thread Pool Library Tests
//
//  Created by Gianluca Bertani on 09/01/13.
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

#import <SenTestingKit/SenTestingKit.h>
#import "LSURLDispatchDelegate.h"


@class LSThreadPool;
@class LSURLDispatcher;

@interface Lightstreamer_Thread_Pool_Library_Tests : SenTestCase <LSURLDispatchDelegate> {
	LSThreadPool *_threadPool;
	LSURLDispatcher *_urlDispatcher;
	
	int _count;
	NSCondition *_semaphore;
	
	NSMutableDictionary *_downloads;
}


@end
