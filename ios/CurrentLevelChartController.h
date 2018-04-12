#import <Foundation/Foundation.h>

#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@class DataLoader;
@class PieChartView;

@interface CurrentLevelChartController : NSObject

- (instancetype)initWithChartView:(PieChartView *)view
                      subjectType:(WKSubject_Type)subjectType
                       dataLoader:(DataLoader *)dataLoader NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) PieChartView *view;
@property(nonatomic) WKSubject_Type subjectType;

- (void)update:(NSArray<WKAssignment *> *)maxLevelAssignments;

@end

NS_ASSUME_NONNULL_END
