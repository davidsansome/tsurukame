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

#import <Foundation/Foundation.h>

#include "proto/Wanikani.pbobjc.h"
@class TKMLevel;
@class DataLoader;

NS_ASSUME_NONNULL_BEGIN

extern const char *kWanikaniSessionCookieName;
extern NSErrorDomain const kTKMClientErrorDomain;
extern const int kTKMLoginErrorCode;

typedef void (^PartialCompletionHandler)(int done, int total);

typedef void (^CookieHandler)(NSError *_Nullable error, NSString *_Nullable cookie);
typedef void (^ApiTokenHandler)(NSError *_Nullable error,
                                NSString *_Nullable apiToken,
                                NSString *_Nullable emailAddress);
typedef void (^AssignmentHandler)(NSError *_Nullable error,
                                  NSString *_Nullable dataUpdatedAtISO8601,
                                  NSArray<TKMAssignment *> *_Nullable assignments);
typedef void (^ProgressHandler)(NSError *_Nullable error);
typedef void (^StudyMaterialsHandler)(NSError *_Nullable error,
                                      NSString *_Nullable dataUpdatedAt,
                                      NSArray<TKMStudyMaterials *> *_Nullable studyMaterials);
typedef void (^UserInfoHandler)(NSError *_Nullable error, TKMUser *_Nullable user);
typedef void (^LevelInfoHandler)(NSError *_Nullable error, NSArray<TKMLevel *> *_Nullable levels);
typedef void (^UpdateStudyMaterialHandler)(NSError *_Nullable error);

@interface TKMClientError : NSError

@property(nonatomic, readonly, nullable) NSURLRequest *request;
@property(nonatomic, readonly, nullable) NSHTTPURLResponse *response;
@property(nonatomic, readonly, nullable) NSData *responseData;

@end

#ifdef __cplusplus
extern "C" {
#endif

extern bool TKMIsClientError(NSError *error);

#ifdef __cplusplus
}
#endif

@interface Client : NSObject

- (instancetype)initWithApiToken:(NSString *)apiToken
                          cookie:(NSString *)cookie
                      dataLoader:(DataLoader *)dataLoader NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic) bool pretendToBeOfflineForTesting;

+ (NSDate *)parseISO8601Date:(NSString *)string;
+ (NSString *)currentISO8601Date;

+ (void)getCookieForUsername:(NSString *)username
                    password:(NSString *)password
                     handler:(CookieHandler)handler;
+ (void)getApiTokenForCookie:(NSString *)cookie handler:(ApiTokenHandler)handler;

- (void)updateApiToken:(NSString *)apiToken cookie:(NSString *)cookie;
- (void)getAssignmentsModifiedAfter:(NSString *_Nullable)date
                    progressHandler:(PartialCompletionHandler)progressHandler
                            handler:(AssignmentHandler)handler;
- (void)getStudyMaterialsModifiedAfter:(NSString *_Nullable)date
                       progressHandler:(PartialCompletionHandler)progressHandler
                               handler:(StudyMaterialsHandler)handler;
- (void)sendProgress:(TKMProgress *)progress handler:(ProgressHandler)handler;
- (void)getUserInfo:(UserInfoHandler)handler;
- (void)getLevelTimes:(LevelInfoHandler)handler;
- (void)updateStudyMaterial:(TKMStudyMaterials *)material
                    handler:(UpdateStudyMaterialHandler)handler;

@end

NS_ASSUME_NONNULL_END
