//
//  LSLog+Internals.h
//  Lightstreamer Thread Pool Library
//
//  Created by Gianluca Bertani on 12/08/15.
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


#pragma mark -
#pragma mark LSLog Internals category

@interface LSLog (Internals)


#pragma mark -
#pragma mark Logging (for internal use only)

+ (void) sourceType:(int)sourceType source:(id)source log:(NSString *)format, ...;
+ (void) log:(NSString *)format, ...;


@end
