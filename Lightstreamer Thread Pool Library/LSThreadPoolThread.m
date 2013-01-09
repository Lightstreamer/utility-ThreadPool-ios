//
//  LSThreadPoolThread.m
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 18/09/12.
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

#import "LSThreadPoolThread.h"
#import "LSInvocation.h"


@implementation LSThreadPoolThread


#pragma mark -
#pragma mark Initialization

+ (LSThreadPoolThread *) threadWithPool:(LSThreadPool *)pool name:(NSString *)name queue:(NSMutableArray *)queue queueMonitor:(NSCondition *)queueMonitor {
	LSThreadPoolThread *thread= [[LSThreadPoolThread alloc] initWithPool:pool name:name queue:queue queueMonitor:queueMonitor];
	
	return [thread autorelease];
}

- (id) initWithPool:(LSThreadPool *)pool name:(NSString *)name queue:(NSMutableArray *)queue queueMonitor:(NSCondition *)queueMonitor {
	if ((self = [super init])) {
		
		// Initialization
		_pool= pool;
		_name= [name retain];
		_queue= [queue retain];
		_queueMonitor= [queueMonitor retain];
		
		// Use a random loop time to avoid periodic delays
		int random= 0;
		SecRandomCopyBytes(kSecRandomDefault, sizeof(random), (uint8_t *) &random);
		_loopInterval= 0.5 + ((double) (ABS(random) % 1000)) / 1000.0;
		
		_running= YES;
		
		[self start];
	}
	
	return self;
}

- (void) dealloc {
	[self dispose];
	
	[_name release];
	[_queue release];
	[_queueMonitor release];
	
	[super dealloc];
}

- (void) dispose {
	_running= NO;
}


#pragma mark -
#pragma mark Thread run loop

- (void) main {
	NSAutoreleasePool *pool= [[NSAutoreleasePool alloc] init];
	
	@try {
		
		// Local retain: they could be released while the thread is running
		[_name retain];
		[_queue retain];
		[_queueMonitor retain];
		
		while (_running) {
			NSAutoreleasePool *internalPool= [[NSAutoreleasePool alloc] init];
			
			LSInvocation *invocation= nil;
			@try {
				[_queueMonitor lock];
				
				if ([_queue count] == 0)
					[_queueMonitor waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:_loopInterval]];
				
				if ([_queue count] > 0) {
					invocation= [[_queue objectAtIndex:0] retain];
					
					[_queue removeObjectAtIndex:0];
				}
				
				[_queueMonitor unlock];
				
				if (invocation) {
					_working= YES;

					[invocation.target performSelector:invocation.selector withObject:invocation.argument];
					
					_lastActivity= [[NSDate date] timeIntervalSinceReferenceDate];
					_working= NO;
				}
				
			} @catch (NSException *e) {
				NSLog(@"LSThreadPoolThread: exception caught while running thread %@: %@ (user info: %@)", _name, e, [e userInfo]);
				
			} @finally {
				[invocation release];
				
				[internalPool drain];
			}
		}
		
	} @finally {
		[_name release];
		[_queue release];
		[_queueMonitor release];

		[pool drain];
	}
}


#pragma mark -
#pragma mark Properties

@synthesize working= _working;
@synthesize lastActivity= _lastActivity;


@end
