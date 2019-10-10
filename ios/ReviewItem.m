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
#import "Settings.h"
#import "Tsurukame-Swift.h"
#import "proto/Wanikani+Convenience.h"

@implementation ReviewItem

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<TKMAssignment *> *)assignments
                                          dataLoader:(DataLoader *)dataLoader {
  NSMutableArray *ret = [NSMutableArray array];
  for (TKMAssignment *assignment in assignments) {
    if (![dataLoader isValidSubjectID:assignment.subjectId]) {
      continue;
    }

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
    if (![dataLoader isValidSubjectID:assignment.subjectId]) {
      continue;
    }

    if (assignment.isLessonStage) {
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

- (NSUInteger)getSubjectTypeIndex:(TKMSubject_Type)type {
  for (int i = 0; i < Settings.lessonOrder.count; i++) {
    if ([Settings.lessonOrder objectAtIndex:i].intValue == type) {
      return i;
    }
  }
  return 0;
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
  if (self.assignment.level < other.assignment.level) {
    return Settings.prioritizeCurrentLevel ? NSOrderedDescending : NSOrderedAscending;
  } else if (self.assignment.level > other.assignment.level) {
    return Settings.prioritizeCurrentLevel ? NSOrderedAscending : NSOrderedDescending;
  }

  if ([Settings.lessonOrder count]) {
    NSUInteger selfIndex = [self getSubjectTypeIndex:self.assignment.subjectType];
    NSUInteger otherIndex = [self getSubjectTypeIndex:other.assignment.subjectType];
    if (selfIndex < otherIndex) {
      return NSOrderedAscending;
    } else if (selfIndex > otherIndex) {
      return NSOrderedDescending;
    }
  }

  if (self.assignment.subjectId < other.assignment.subjectId) {
    return NSOrderedAscending;
  } else if (self.assignment.subjectId > other.assignment.subjectId) {
    return NSOrderedDescending;
  }

  return NSOrderedSame;
}

- (void)reset {
  _answer.hasMeaningWrong = NO;
  _answer.hasReadingWrong = NO;
  _answeredMeaning = NO;
  _answeredReading = NO;
}

@end
