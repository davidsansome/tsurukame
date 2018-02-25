#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CombinedChartView;

@interface UpcomingReviewsChartController : NSObject

- (instancetype)initWithChartView:(CombinedChartView *)view NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) CombinedChartView *view;

- (void)update:(NSArray<NSNumber *> *)upcomingReviews
currentReviewCount:(int)currentReviewCount
        atDate:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
