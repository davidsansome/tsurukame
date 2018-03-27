#import <Foundation/Foundation.h>

#import "proto/Wanikani.pbobjc.h"

typedef NS_ENUM(NSInteger, WKTaskType) {
  kWKTaskTypeReading,
  kWKTaskTypeMeaning,
  
  kWKTaskType_Max,
};

@interface ReviewItem : NSObject

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<WKAssignment *> *)assignments;
+ (NSArray<ReviewItem *> *)assignmentsReadyForLesson:(NSArray<WKAssignment *> *)assignments;

- (instancetype)initFromAssignment:(WKAssignment *)assignment NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) WKAssignment *assignment;
@property (nonatomic) bool answeredReading;
@property (nonatomic) bool answeredMeaning;
@property (nonatomic) WKProgress *answer;

- (NSComparisonResult)compareForLessons:(ReviewItem *)other;

@end
