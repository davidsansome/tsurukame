//
//  Tsurukame
//
//  Created by André Arko on 7/14/19.
//  Copyright © 2019 David Sansome. All rights reserved.
//

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
  return;
}

@end
