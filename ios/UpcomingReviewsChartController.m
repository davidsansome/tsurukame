#import "UpcomingReviewsChartController.h"

#import "Style.h"

#import "wk-Swift.h"

@interface UpcomingReviewsXAxisValueFormatter : NSObject <IChartAxisValueFormatter>
- (instancetype)initWithStartTime:(NSDate *)startTime;
@end

@implementation UpcomingReviewsXAxisValueFormatter {
  NSDate *_startTime;
  NSDateFormatter *_dateFormatter;
}

- (instancetype)initWithStartTime:(NSDate *)startTime {
  self = [super init];
  if (self) {
    _startTime = startTime;
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setLocalizedDateFormatFromTemplate:@"ha"];
  }
  return self;
}

- (NSString * _Nonnull)stringForValue:(double)value
                                 axis:(ChartAxisBase * _Nullable)axis {
  if (value == 0) {
    return @"";
  }
  NSDate *date = [_startTime dateByAddingTimeInterval:value * 60 * 60];
  return [_dateFormatter stringFromDate:date];
}

@end


@implementation UpcomingReviewsChartController

- (instancetype)initWithChartView:(CombinedChartView *)view {
  self = [super init];
  if (self) {
    _view = view;
    _view.leftAxis.axisMinimum = 0.f;
    _view.rightAxis.axisMinimum = 0.f;
    _view.rightAxis.enabled = NO;
    _view.xAxis.labelPosition = XAxisLabelPositionBottom;
    _view.xAxis.drawGridLinesEnabled = NO;
    _view.legend.enabled = NO;
    _view.chartDescription = nil;
    _view.userInteractionEnabled = NO;
  }
  return self;
}

- (void)update:(NSArray<NSNumber *> *)upcomingReviews
currentReviewCount:(int)currentReviewCount
        atDate:(nonnull NSDate *)date {
  NSMutableArray<BarChartDataEntry *> *hourlyData = [NSMutableArray array];
  NSMutableArray<ChartDataEntry *> *cumulativeData = [NSMutableArray array];
  
  // Add the reviews pending now.
  int cumulativeReviews = currentReviewCount;
  [cumulativeData addObject:[[ChartDataEntry alloc] initWithX:0 y:cumulativeReviews]];
  
  // Add upcoming hourly reviews.
  for (int i = 0; i < upcomingReviews.count; ++i) {
    int x = i + 1;
    int y = [upcomingReviews[i] intValue];
    cumulativeReviews += y;
    [hourlyData addObject:[[BarChartDataEntry alloc] initWithX:x y:y]];
    [cumulativeData addObject:[[ChartDataEntry alloc] initWithX:x y:cumulativeReviews]];
  }
  
  LineChartDataSet *lineDataSet = [[LineChartDataSet alloc] initWithValues:cumulativeData label:nil];
  lineDataSet.drawValuesEnabled = NO;
  lineDataSet.drawCircleHoleEnabled = NO;
  lineDataSet.circleRadius = 1.5f;
  lineDataSet.colors = @[WKVocabularyColor2()];
  lineDataSet.circleColors = @[WKVocabularyColor2()];
  
  BarChartDataSet *barDataSet = [[BarChartDataSet alloc] initWithValues:hourlyData label:nil];
  barDataSet.axisDependency = AxisDependencyRight;
  barDataSet.colors = @[WKRadicalColor2()];
  
  CombinedChartData *data = [[CombinedChartData alloc] init];
  data.lineData = [[LineChartData alloc] initWithDataSet:lineDataSet];
  data.barData = [[BarChartData alloc] initWithDataSet:barDataSet];
  
  _view.data = data;
  _view.rightAxis.axisMaximum = barDataSet.yMax;
  _view.xAxis.valueFormatter = [[UpcomingReviewsXAxisValueFormatter alloc] initWithStartTime:date];
}

@end
