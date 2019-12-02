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

#import "Client.h"
#import "Reachability.h"
#import "proto/Wanikani+Convenience.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kLocalCachingClientAvailableItemsChangedNotification;
extern NSNotificationName kLocalCachingClientPendingItemsChangedNotification;
extern NSNotificationName kLocalCachingClientUserInfoChangedNotification;
extern NSNotificationName kLocalCachingClientSrsLevelCountsChangedNotification;
extern NSNotificationName kLocalCachingClientUnauthorizedNotification;

typedef void (^SyncProgressHandler)(float progress);

@interface LocalCachingClient : NSObject

@property(nonatomic, readonly) Client *client;
@property(nonatomic, readonly) int availableLessonCount;
@property(nonatomic, readonly) int availableReviewCount;
@property(nonatomic, readonly) NSArray<NSNumber *> *upcomingReviews;
@property(nonatomic, readonly) int pendingProgress;
@property(nonatomic, readonly) int pendingStudyMaterials;

+ (NSURL *)databaseFileUrl;

- (instancetype)initWithClient:(Client *)client
                    dataLoader:(DataLoader *)dataLoader
                  reachability:(Reachability *)reachability NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Sends pending review progress and study material updates, fetches updates.  The progress
// handler is always executed on the main queue.
- (void)syncWithProgressHandler:(SyncProgressHandler)syncProgressHandler quick:(bool)quick;

// Getters: query the database and return data immediately, without making network requests.
- (NSArray<TKMAssignment *> *)getAllAssignments;
- (nullable TKMStudyMaterials *)getStudyMaterialForID:(int)subjectID;
- (nullable TKMUser *)getUserInfo;
- (NSArray<TKMProgress *> *)getAllPendingProgress;
- (TKMAssignment *)getAssignmentForID:(int)subjectID;
- (nullable NSArray<TKMAssignment *> *)getAssignmentsAtLevel:(int)level;
- (nullable NSArray<TKMAssignment *> *)getAssignmentsAtUsersCurrentLevel;
- (int)getSrsLevelCount:(TKMSRSStageCategory)level;
- (int)getGuruKanjiCount;
- (NSTimeInterval)getAverageRemainingLevelTime;

// Setters: save the data to the database and return immediately, make network requests in the
// background.
- (void)sendProgress:(NSArray<TKMProgress *> *)progress;
- (void)updateStudyMaterial:(TKMStudyMaterials *)material;

// Delete everything: use when a user logs out.
- (void)clearAllDataAndClose;
- (void)clearAllData;

@end

NS_ASSUME_NONNULL_END
