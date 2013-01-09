//
//  LSURLDispatcherThread.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 10/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface LSURLDispatcherThread : NSThread {
    NSTimeInterval _loopInterval;
    
    NSTimeInterval _lastActivity;
    
    BOOL _running;
}


#pragma mark -
#pragma mark Execution control

- (void) stopThread;


#pragma mark -
#pragma mark Properties

@property (nonatomic, assign) NSTimeInterval lastActivity;


@end
