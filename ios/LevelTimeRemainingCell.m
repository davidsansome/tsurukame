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

#import "LevelTimeRemainingCell.h"
#import "Tables/TKMSubjectModelItem.h"
#import "TKMServices.h"
#import "DataLoader.h"
#import "LocalCachingClient.h"

@implementation LevelTimeRemainingCell {
  TKMServices *_services;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)update:(NSArray<TKMAssignment *> *)assignments {
  NSDate* guruDate = [NSDate date];

  for (TKMAssignment* assignment in assignments) {
    if (assignment.hasPassedAt) { continue; }
    if (assignment.subjectType == TKMSubject_Type_Vocabulary) { continue; }

    if (!assignment.hasAvailableAt) {
      NSTimeInterval average = [_services.localCachingClient getAverageRemainingLevelTime];
      NSDate* averageDate = [NSDate dateWithTimeIntervalSinceNow:average];
      [self setRemaining: averageDate average: YES];
      return;
    }

    TKMSubject *subject = [_services.dataLoader loadSubject:assignment.subjectId];
    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                  assignment:assignment
                                                                    delegate:self];

    NSDate* itemDate = [item guruDate];
    if ([itemDate compare:guruDate] == NSOrderedDescending) {
      guruDate = itemDate;
    }
  }

  [self setRemaining:guruDate average: NO];
}

- (void)setRemaining:(NSDate *) finish average:(BOOL) average {
  if (average) {
    self.textLabel.text = @"Time Remaining (average)";
  } else {
    self.textLabel.text = @"Time Remaining";
  }

  if ([[NSDate date] compare:finish] == NSOrderedDescending) {
    self.detailTextLabel.text = @"Now";
  } else {
    self.detailTextLabel.text = [self intervalString:finish];
  }
}

- (NSString *)intervalString:(NSDate *)date {
  NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
  formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;

  int componentsBitMask = NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute;
  NSDateComponents *components = [[NSCalendar currentCalendar]
                                  components:componentsBitMask
                                  fromDate:[NSDate date]
                                  toDate:date
                                  options:0];

  // Only show minutes after there are no hours left
  if (components.hour > 0) {
    [components setMinute: 0];
  }

  return [formatter stringFromDateComponents:components];
}

- (void)didTapSubject:(TKMSubject *)subject {
}

@end
