#import "MainViewController.h"

#import "LessonsViewController.h"
#import "NSDate+TimeAgo.h"
#import "NSString+MD5.h"
#import "ReviewViewController.h"
#import "Style.h"
#import "UserDefaults.h"
#import "proto/Wanikani+Convenience.h"

@import Charts;

static const NSInteger kItemsPerLesson = 5;

static const char *kDefaultProfileImageURL = "https://cdn.wanikani.com/default-avatar-300x300-20121121.png";
static const int kProfileImageSize = 80;

static NSURL *UserProfileImageURL(NSString *emailAddress) {
  emailAddress = [emailAddress stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  emailAddress = [emailAddress lowercaseString];
  NSString *hash = [emailAddress MD5];
  
  int size = kProfileImageSize * [[UIScreen mainScreen] scale];
  
  return [NSURL URLWithString:[NSString stringWithFormat:@"https://www.gravatar.com/avatar/%@.jpg?s=%d&d=%s",
                               hash, size, kDefaultProfileImageURL]];
}

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

@interface MainViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *userCell;
@property (weak, nonatomic) IBOutlet UIImageView *userImageView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userLevelLabel;

@property (weak, nonatomic) IBOutlet UITableViewCell *lessonsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *reviewsCell;

@property (weak, nonatomic) IBOutlet CombinedChartView *upcomingReviewsChartView;

@end

@implementation MainViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(clientBusyChanged:)
               name:kLocalCachingClientBusyChangedNotification
             object:_localCachingClient];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.refreshControl = [[UIRefreshControl alloc] init];
  self.refreshControl.tintColor = [UIColor darkGrayColor];
  self.refreshControl.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
  NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"Pull to refresh..."];
  self.refreshControl.attributedTitle = title;
  [self.refreshControl addTarget:self
                          action:@selector(didPullToRefresh)
                forControlEvents:UIControlEventValueChanged];
  
  UIColor *userImageBorderColor = WKVocabularyColor();
  CGFloat h,s,b;
  [userImageBorderColor getHue:&h saturation:&s brightness:&b alpha:nil];
  userImageBorderColor = [UIColor colorWithHue:h saturation:s/2.f brightness:b alpha:1.f];
  
  _userImageView.layer.masksToBounds = YES;
  _userImageView.layer.cornerRadius = _userImageView.layer.bounds.size.height / 2 + 1;
  _userImageView.layer.borderWidth = 4.f;
  _userImageView.layer.borderColor = userImageBorderColor.CGColor;
  
  CAGradientLayer *userGradientLayer = [CAGradientLayer layer];
  userGradientLayer.frame = _userCell.bounds;
  userGradientLayer.colors = WKVocabularyGradient();
  [_userCell.layer insertSublayer:userGradientLayer atIndex:0];
  
  _upcomingReviewsChartView.leftAxis.axisMinimum = 0.f;
  _upcomingReviewsChartView.rightAxis.axisMinimum = 0.f;
  _upcomingReviewsChartView.rightAxis.enabled = NO;
  _upcomingReviewsChartView.xAxis.labelPosition = XAxisLabelPositionBottom;
  _upcomingReviewsChartView.xAxis.drawGridLinesEnabled = NO;
  _upcomingReviewsChartView.legend.enabled = NO;
  _upcomingReviewsChartView.chartDescription = nil;
  _upcomingReviewsChartView.userInteractionEnabled = NO;
}

- (void)viewWillAppear:(BOOL)animated {
  [self updateUserInfo];
  [self updateLessonAndReviewCounts];
  [_localCachingClient update];
  
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (void)clientBusyChanged:(NSNotification *)notification {
  // An update just finished - update the lesson and review counts.
  if (!_localCachingClient.isBusy) {
    [self updateLessonAndReviewCounts];
  }
}

- (void)updateUserInfo {
  WKUser *user = _localCachingClient.getUserInfo;
  
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLRequest *req = [NSURLRequest requestWithURL:UserProfileImageURL([UserDefaults userEmailAddress])];
  
  NSURLSessionDataTask *task = [session dataTaskWithRequest:req
                                          completionHandler:^(NSData * _Nullable data,
                                                              NSURLResponse * _Nullable response,
                                                              NSError * _Nullable error) {
                                            if (error) {
                                              NSLog(@"Error fetching profile photo: %@", error);
                                              return;
                                            }
                                            UIImage *image = [UIImage imageWithData:data scale:[[UIScreen mainScreen] scale]];
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                              _userImageView.image = image;
                                            });
                                          }];
  [task resume];
  
  _userNameLabel.text = user.username;
  _userLevelLabel.text = [NSString stringWithFormat:@"Level %d \u00B7 joined %@",
                          user.level,
                          [user.startedAtDate timeAgoSinceNow:[NSDate date]]];
}

- (void)updateLessonAndReviewCounts {
  __weak MainViewController *weakSelf = self;
  [_localCachingClient getAllAssignments:^(NSError *error, NSArray<WKAssignment *> *assignments) {
    if (error) {
      [weakSelf updateLessonCount:-1 reviewCount:-1 upcomingReviews:nil];
      return;
    }
    int lessons = 0;
    int reviews = 0;
    
    NSDate *now = [NSDate date];
    NSMutableArray<NSNumber *> *reviewsInHours = [NSMutableArray arrayWithCapacity:24];
    for (int i = 0; i < 24; i++) {
      [reviewsInHours addObject:@(0)];
    }
    
    for (WKAssignment *assignment in assignments) {
      if (assignment.isLessonStage) {
        lessons ++;
      } else if (assignment.isReviewStage) {
        NSTimeInterval interval = [assignment.availableAtDate timeIntervalSinceDate:now];
        if (interval <= 0) {
          reviews ++;
          continue;
        }
        
        for (int hour = 0; hour < 24; hour++) {
          if (interval < (hour + 1) * 60 * 60) {
            [reviewsInHours setObject:[NSNumber numberWithInt:[reviewsInHours[hour] intValue] + 1]
                   atIndexedSubscript:hour];
            break;
          }
        }
      }
    }
    [weakSelf updateLessonCount:lessons reviewCount:reviews upcomingReviews:reviewsInHours];
  }];
}

- (void)updateLessonCount:(int)lessonCount
              reviewCount:(int)reviewCount
          upcomingReviews:(NSArray<NSNumber *> *)upcomingReviews {
  __weak MainViewController *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    weakSelf.lessonsCell.detailTextLabel.text = (lessonCount < 0) ? @"-" : [@(lessonCount) stringValue];
    weakSelf.reviewsCell.detailTextLabel.text = (reviewCount < 0) ? @"-" : [@(reviewCount) stringValue];
    
    NSMutableArray<BarChartDataEntry *> *hourlyData = [NSMutableArray array];
    NSMutableArray<ChartDataEntry *> *cumulativeData = [NSMutableArray array];
    
    // Add the reviews pending now.
    [cumulativeData addObject:[[ChartDataEntry alloc] initWithX:0 y:reviewCount]];
    
    // Add upcoming hourly reviews.
    int cumulativeReviews = reviewCount;
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
    lineDataSet.colors = @[WKVocabularyColor()];
    lineDataSet.circleColors = @[WKVocabularyColor()];
    
    BarChartDataSet *barDataSet = [[BarChartDataSet alloc] initWithValues:hourlyData label:nil];
    barDataSet.axisDependency = AxisDependencyRight;
    barDataSet.colors = @[WKRadicalColor()];
    
    CombinedChartData *data = [[CombinedChartData alloc] init];
    data.lineData = [[LineChartData alloc] initWithDataSet:lineDataSet];
    data.barData = [[BarChartData alloc] initWithDataSet:barDataSet];
    
    _upcomingReviewsChartView.data = data;
    _upcomingReviewsChartView.rightAxis.axisMaximum = barDataSet.yMax;
    _upcomingReviewsChartView.xAxis.valueFormatter =
        [[UpcomingReviewsXAxisValueFormatter alloc] initWithStartTime:[NSDate date]];
  });
}

- (void)didPullToRefresh {
  [self.refreshControl endRefreshing];
  if (!_reachability.isReachable) {
    return;
  }
  [_localCachingClient update];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"startReview"]) {
    ReviewViewController *vc = (ReviewViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    
    [_localCachingClient getAllAssignments:^(NSError *error, NSArray<WKAssignment *> *assignments) {
      if (error) {
        NSLog(@"Failed to get assignments: %@", error);
        return;
      }
      NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForReview:assignments];
      [vc startReviewWithItems:items];
    }];
  } else if ([segue.identifier isEqualToString:@"startLessons"]) {
    LessonsViewController *vc = (LessonsViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    
    [_localCachingClient getAllAssignments:^(NSError *error, NSArray<WKAssignment *> *assignments) {
      if (error) {
        NSLog(@"Failed to get assignments: %@", error);
        return;
      }
      NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForLesson:assignments];
      if (items.count > kItemsPerLesson) {
        items = [items subarrayWithRange:NSMakeRange(0, kItemsPerLesson)];
      }
      
      dispatch_async(dispatch_get_main_queue(), ^{
        vc.items = items;
      });
    }];
  }
}

@end
