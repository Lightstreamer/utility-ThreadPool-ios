//
//  LSURLAuthenticationChallengeSender.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 11/11/15.
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
 @brief A wrapper for the sender of an authentication challenge. <b>This class should not be used directly</b>.
 @see LSURLDispatcher.
 */
@interface LSURLAuthenticationChallengeSender : NSObject <NSURLAuthenticationChallengeSender>


#pragma mark -
#pragma mark Properties (for internal use only)

@property (nonatomic, readonly) NSURLSessionAuthChallengeDisposition disposition;
@property (nonatomic, readonly) NSURLCredential *credential;


@end
