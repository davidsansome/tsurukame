// Copyright 2018 David Sansome
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "proto/Wanikani.pbobjc.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const char *kWanikaniSessionCookieName;
extern NSErrorDomain WKClientErrorDomain;

typedef void (^ApiTokenHandler)(NSError * _Nullable error,
                                NSString * _Nullable apiToken,
                                NSString * _Nullable emailAddress);
typedef void (^AssignmentHandler)(NSError * _Nullable error,
                                  NSArray<WKAssignment *> * _Nullable assignments);
typedef void (^ProgressHandler)(NSError * _Nullable error);
typedef void (^StudyMaterialsHandler)(NSError * _Nullable error,
                                      NSArray<WKStudyMaterials *> * _Nullable studyMaterials);
typedef void (^UserInfoHandler)(NSError * _Nullable error, WKUser * _Nullable user);
typedef void (^UpdateStudyMaterialHandler)(NSError * _Nullable error);

@interface Client : NSObject

- (instancetype)initWithApiToken:(NSString *)apiToken
                          cookie:(NSString *)cookie NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) NSDateFormatter *dateFormatter;
@property (nonatomic, readonly) NSString *currentISO8601Time;

@property (nonatomic) bool pretendToBeOfflineForTesting;

+ (void)getApiTokenForCookie:(NSString *)cookie
                     handler:(ApiTokenHandler)handler;
- (void)getAssignmentsModifiedAfter:(NSString *)date
                            handler:(AssignmentHandler)handler;
- (void)sendProgress:(NSArray<WKProgress *> *)progress
             handler:(ProgressHandler _Nullable)handler;
- (void)getStudyMaterialsModifiedAfter:(NSString *)date
                               handler:(StudyMaterialsHandler)handler;
- (void)getUserInfo:(UserInfoHandler)handler;
- (void)updateStudyMaterial:(WKStudyMaterials *)material
                    handler:(UpdateStudyMaterialHandler)handler;

@end

NS_ASSUME_NONNULL_END
