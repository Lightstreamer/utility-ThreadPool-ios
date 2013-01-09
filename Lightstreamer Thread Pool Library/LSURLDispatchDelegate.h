//
//  LSURLDispatchDelegate.h
//  Lightstreamer client for iOS
//
//  Created by Gianluca Bertani on 03/09/12.
//  Copyright (c) 2012 Weswit srl. All rights reserved.
//

#import <Foundation/Foundation.h>


@class LSURLDispatchOperation;

@protocol LSURLDispatchDelegate <NSObject>


- (void) dispatchOperation:(LSURLDispatchOperation *)operation didReceiveResponse:(NSURLResponse *)response;
- (void) dispatchOperation:(LSURLDispatchOperation *)operation didReceiveData:(NSData *)data;
- (void) dispatchOperation:(LSURLDispatchOperation *)operation didFailWithError:(NSError *)error;
- (void) dispatchOperationDidFinish:(LSURLDispatchOperation *)operation;


@end
