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
