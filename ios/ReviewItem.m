#import "ReviewItem.h"
#import "proto/Wanikani+Convenience.h"

@implementation ReviewItem

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<WKAssignment *> *)assignments {
  NSMutableArray *ret = [NSMutableArray array];
  for (WKAssignment *assignment in assignments) {
    if (assignment.isReviewStage && assignment.availableAtDate.timeIntervalSinceNow < 0) {
      [ret addObject:[[ReviewItem alloc] initFromAssignment:assignment]];
    }
  }
  return ret;
}

+ (NSArray<ReviewItem *> *)assignmentsReadyForLesson:(NSArray<WKAssignment *> *)assignments {
  NSMutableArray *ret = [NSMutableArray array];
  for (WKAssignment *assignment in assignments) {
    if (assignment.isLessonStage) {
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
    _answer.isLesson = assignment.isLessonStage;
  }
  return self;
}

- (NSComparisonResult)compareForLessons:(ReviewItem *)other {
  #define COMPARE(field) \
    if (self.field < other.field) { \
      return NSOrderedAscending; \
    } \
    if (self.field > other.field) { \
      return NSOrderedDescending; \
    }

  COMPARE(assignment.subjectType);
  COMPARE(assignment.level);
  COMPARE(assignment.subjectId);
  return NSOrderedSame;

  #undef COMPARE
}

@end
