//
//  ReviewItem.m
//  wk
//
//  Created by David Sansome on 28/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "ReviewItem.h"

@implementation ReviewItem

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<WKAssignment *> *)assignments {
  NSMutableArray *ret = [NSMutableArray array];
  for (WKAssignment *assignment in assignments) {
    if (!assignment.hasAvailableAt) {
      continue;
    }
    NSDate *readyForReview = [NSDate dateWithTimeIntervalSince1970:assignment.availableAt];
    if ([readyForReview timeIntervalSinceNow] < 0) {
      NSLog(@"Ready: %@", assignment);
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

- (instancetype)initFromAssignment:(WKAssignment *)assignment {
  if (self = [super init]) {
    _assignment = assignment;
  }
  return self;
}

@end
