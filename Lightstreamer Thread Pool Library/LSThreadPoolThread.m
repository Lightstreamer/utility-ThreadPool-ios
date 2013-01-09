//
//  LSThreadPoolThread.m
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 18/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import "LSThreadPoolThread.h"
#import "LSInvocation.h"
#import "LSLog.h"


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
				if ([LSLog isSourceTypeEnabled:LOG_SRC_THREAD_POOL])
					[LSLog sourceType:LOG_SRC_THREAD_POOL source:_pool log:@"Exception caught while running thread %@: %@ (user info: %@)", _name, e, [e userInfo]];
				
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
