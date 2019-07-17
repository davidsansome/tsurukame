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
      NSTimeInterval average = [_services.localCachingClient getAverageLevelTime];
      NSDate* averageDate = [NSDate dateWithTimeIntervalSinceNow:average];
      NSString* interval = [self intervalString:averageDate];

      [self setInterval: [NSString stringWithFormat: @"average %@", interval]];
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

  if ([[NSDate date] compare:guruDate] == NSOrderedDescending) {
    [self setInterval:@"Now"];
    return;
  }

  [self setInterval:[self intervalString:guruDate]];
}

- (void)setInterval:(NSString *) text {
  self.detailTextLabel.text = text;
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
