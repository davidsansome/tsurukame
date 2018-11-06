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

@class DataLoader;

typedef NS_ENUM(NSInteger, TKMTaskType) {
  kTKMTaskTypeReading,
  kTKMTaskTypeMeaning,

  kTKMTaskType_Max,
};

@interface ReviewItem : NSObject

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<TKMAssignment *> *)assignments;
+ (NSArray<ReviewItem *> *)assignmentsReadyForLesson:(NSArray<TKMAssignment *> *)assignments
                                          dataLoader:(DataLoader *)dataLoader;

- (instancetype)initFromAssignment:(TKMAssignment *)assignment NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) TKMAssignment *assignment;
@property(nonatomic) bool answeredReading;
@property(nonatomic) bool answeredMeaning;
@property(nonatomic) TKMProgress *answer;

- (NSComparisonResult)compareForLessons:(ReviewItem *)other;

@end
