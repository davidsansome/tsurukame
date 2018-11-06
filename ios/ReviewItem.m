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

#import "ReviewItem.h"
#import "DataLoader.h"
#import "proto/Wanikani+Convenience.h"

@implementation ReviewItem

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<TKMAssignment *> *)assignments {
  NSMutableArray *ret = [NSMutableArray array];
  for (TKMAssignment *assignment in assignments) {
    if (assignment.isReviewStage && assignment.availableAtDate.timeIntervalSinceNow < 0) {
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

+ (NSArray<ReviewItem *> *)assignmentsReadyForLesson:(NSArray<TKMAssignment *> *)assignments
                                          dataLoader:(DataLoader *)dataLoader {
  NSMutableArray *ret = [NSMutableArray array];
  for (TKMAssignment *assignment in assignments) {
    // Protect against new subjects getting added to WaniKani.  This will assert in developer builds
    // but should just skip new subjects in release builds.
    if (![dataLoader isValidSubjectID:assignment.subjectId]) {
      NSAssert(false, @"Invalid subject ID in assignment: %@", assignment);
      continue;
    }

    if (assignment.isLessonStage) {
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

- (instancetype)initFromAssignment:(TKMAssignment *)assignment {
  if (self = [super init]) {
    _assignment = assignment;
    _answer = [[TKMProgress alloc] init];
    _answer.assignment = assignment;
    _answer.isLesson = assignment.isLessonStage;
  }
  return self;
}

- (NSComparisonResult)compareForLessons:(ReviewItem *)other {
#define COMPARE(field)            \
  if (self.field < other.field) { \
    return NSOrderedAscending;    \
  }                               \
  if (self.field > other.field) { \
    return NSOrderedDescending;   \
  }

  COMPARE(assignment.level);
  COMPARE(assignment.subjectType);
  COMPARE(assignment.subjectId);
  return NSOrderedSame;

#undef COMPARE
}

@end
