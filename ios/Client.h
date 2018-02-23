//
//  Client.h
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

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
