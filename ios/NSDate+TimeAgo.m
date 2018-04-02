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

#import "NSDate+TimeAgo.h"

@implementation NSDate (TimeAgo)

- (NSString *)timeAgoSinceNow:(NSDate *)now {
  NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
  formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
  
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components =
      [calendar components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitWeekOfMonth|
                            NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|
                            NSCalendarUnitSecond)
                  fromDate:self
                    toDate:now
                   options:0];
  
  if (components.year > 0) {
    formatter.allowedUnits = NSCalendarUnitYear;
  } else if (components.month > 0) {
    formatter.allowedUnits = NSCalendarUnitMonth;
  } else if (components.weekOfMonth > 0) {
    formatter.allowedUnits = NSCalendarUnitWeekOfMonth;
  } else if (components.day > 0) {
    formatter.allowedUnits = NSCalendarUnitDay;
  } else if (components.hour > 0) {
    formatter.allowedUnits = NSCalendarUnitHour;
  } else if (components.minute > 0) {
    formatter.allowedUnits = NSCalendarUnitMinute;
  } else {
    formatter.allowedUnits = NSCalendarUnitSecond;
  }
  
  return [NSString stringWithFormat:@"%@ ago", [formatter stringFromDateComponents:components]];
}

@end
