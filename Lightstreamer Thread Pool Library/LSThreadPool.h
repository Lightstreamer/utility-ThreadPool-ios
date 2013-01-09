//
//  LSThreadPool.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 17/09/12.
//  Copyright (c) 2012-2013 Weswit srl. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  * Neither the name of Weswit srl nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/Foundation.h>


@class LSInvocation;

@interface LSThreadPool : NSObject {
	NSString *_name;
	int _size;

	NSMutableArray *_threads;

	NSMutableArray *_invocationQueue;
	NSCondition *_monitor;
	
    int _nextThreadId;
	BOOL _disposed;
}


#pragma mark -
#pragma mark Initialization

+ (LSThreadPool *) poolWithName:(NSString *)name size:(int)poolSize;
- (id) initWithName:(NSString *)name size:(int)poolSize;

- (void) dispose;


#pragma mark -
#pragma mark Invocation scheduling

- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector;
- (LSInvocation *) scheduleInvocationForTarget:(id)target selector:(SEL)selector withObject:(id)object;


#pragma mark -
#pragma mark Properties

@property (nonatomic, readonly) int queueSize;


@end
