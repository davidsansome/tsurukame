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
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kLocalCachingClientAvailableItemsChangedNotification;
extern NSNotificationName kLocalCachingClientPendingItemsChangedNotification;

typedef void (^CompletionHandler)(void);

@interface LocalCachingClient : NSObject

@property(nonatomic, readonly) int availableLessonCount;
@property(nonatomic, readonly) int availableReviewCount;
@property(nonatomic, readonly) NSArray<NSNumber *> *upcomingReviews;
@property(nonatomic, readonly) int pendingProgress;
@property(nonatomic, readonly) int pendingStudyMaterials;

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Sends pending review progress and study material updates, fetches updates.  The completion
// handler is always executed on the main queue.
- (void)sync:(CompletionHandler _Nullable)completionHandler;

// Getters: query the database and return data immediately, without making network requests.
- (NSArray<WKAssignment *> *)getAllAssignments;
- (WKStudyMaterials * _Nullable)getStudyMaterialForID:(int)subjectID;
- (WKUser * _Nullable)getUserInfo;

// Setters: save the data to the database and return immediately, make network requests in the
// background.
- (void)sendProgress:(NSArray<WKProgress *> *)progress;
- (void)updateStudyMaterial:(WKStudyMaterials *)material;

// Delete everything: use when a user logs out.
- (void)clearAllData;

@end

NS_ASSUME_NONNULL_END
