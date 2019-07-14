//
//  LevelTimeRemainingLabel.m
//  Tsurukame
//
//  Created by André Arko on 7/14/19.
//  Copyright © 2019 David Sansome. All rights reserved.
//

#import "LevelTimeRemainingLabel.h"
#import "Tables/TKMSubjectModelItem.h"
#import "TKMServices.h"
#import "DataLoader.h"

@implementation LevelTimeRemainingLabel {
  TKMServices *_services;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)update:(NSArray<TKMAssignment *> *)assignments {
  NSDate* guruDate = [NSDate date];

  for (TKMAssignment* assignment in assignments) {
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
    self.text = @"Now";
    return;
  }

  NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
  formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;

  int componentsBitMask = NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute;
  NSDateComponents *components = [[NSCalendar currentCalendar]
                                  components:componentsBitMask
                                  fromDate:[NSDate date]
                                  toDate:guruDate
                                  options:0];

  // Only show minutes after there are no hours left
  if (components.hour > 0) {
    [components setMinute: 0];
  }

  self.text = [formatter stringFromDateComponents:components];
}

- (void)didTapSubject:(TKMSubject *)subject {
  return;
}

@end
