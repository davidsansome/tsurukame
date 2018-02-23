#import "ReviewItem.h"
#import "proto/Wanikani+Convenience.h"

@implementation ReviewItem

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<WKAssignment *> *)assignments {
  NSMutableArray *ret = [NSMutableArray array];
  for (WKAssignment *assignment in assignments) {
    if (assignment.isReadyForReview) {
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

+ (NSArray<ReviewItem *> *)assignmentsReadyForLesson:(NSArray<WKAssignment *> *)assignments {
  NSMutableArray *ret = [NSMutableArray array];
  for (WKAssignment *assignment in assignments) {
    if (assignment.isReadyForLesson) {
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

- (instancetype)initFromAssignment:(WKAssignment *)assignment {
  if (self = [super init]) {
    _assignment = assignment;
    _answer = [[WKProgress alloc] init];
    _answer.assignmentId = assignment.id_p;
    _answer.subjectId = assignment.subjectId;
    _answer.isLesson = assignment.isReadyForLesson;
  }
  return self;
}

@end
