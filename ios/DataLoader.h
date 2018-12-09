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

#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataLoader : NSObject

@property(nonatomic, readonly) NSInteger count;

- (instancetype)initFromURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/**
 * The highest level this user is allowed to see.  Subjects from higher levels will not be
 * returned.  Never higher than maxSubjectLevel.
 */
@property(nonatomic) int maxLevelGrantedBySubscription;

/** The highest level available in the database. */
@property(nonatomic, readonly) int maxSubjectLevel;

/** Array of subject IDs that have been deleted. */
@property(nonatomic, readonly) GPBInt32Array *deletedSubjectIDs;

- (bool)isValidSubjectID:(int)subjectID;

/** Returns the subject with the given ID, or nil if higher than maxLevelGrantedBySubscription. */
- (nullable TKMSubject *)loadSubject:(int)subjectID;

/** Returns all subjects in levels granted by the user's subscription.  This is quite slow. */
- (NSArray<TKMSubject *> *)loadAllSubjects;

/** Returns the IDs of subjects in the given level, or nil if higher than maxLevelGrantedBySubscription. */
- (nullable TKMSubjectsByLevel *)subjectsByLevel:(int)level;

@end

NS_ASSUME_NONNULL_END
