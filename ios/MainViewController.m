#import "MainViewController.h"

#import "LessonsViewController.h"
#import "NSDate+TimeAgo.h"
#import "NSString+MD5.h"
#import "ReviewViewController.h"
#import "Style.h"
#import "UpcomingReviewsChartController.h"
#import "UserDefaults.h"
#import "proto/Wanikani+Convenience.h"

#import <UserNotifications/UserNotifications.h>

@class CombinedChartView;

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

static void SetTableViewCellCount(UITableViewCell *cell, int count) {
  cell.detailTextLabel.text = (count < 0) ? @"-" : [@(count) stringValue];

  BOOL enabled = count > 0;
  cell.userInteractionEnabled = enabled;
  cell.textLabel.enabled = enabled;
  cell.detailTextLabel.enabled = enabled;
}


@interface MainViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *userCell;
@property (weak, nonatomic) IBOutlet UIView *userImageContainer;
@property (weak, nonatomic) IBOutlet UIImageView *userImageView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userLevelLabel;

@property (weak, nonatomic) IBOutlet UITableViewCell *lessonsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *reviewsCell;

@property (weak, nonatomic) IBOutlet UILabel *queuedItemsLabel;
@property (weak, nonatomic) IBOutlet UILabel *queuedItemsSubtitleLabel;

@property (weak, nonatomic) IBOutlet CombinedChartView *upcomingReviewsChartView;

@end

@implementation MainViewController {
  UpcomingReviewsChartController *_chartController;
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
  
  WKAddShadowToView(_userImageContainer, 2, 0.4, 4);
  WKAddShadowToView(_userNameLabel, 1, 0.4, 4);
  WKAddShadowToView(_userLevelLabel, 1, 0.2, 2);
  
  _chartController =
      [[UpcomingReviewsChartController alloc] initWithChartView:_upcomingReviewsChartView];
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(clientStateChanged:)
             name:kLocalCachingClientStateChangedNotification
           object:_localCachingClient];
  [self clientStateChanged:nil];
}

- (void)viewDidLayoutSubviews {
  // Set rounded corners on the user image.
  CGFloat cornerRadius = _userImageContainer.bounds.size.height / 2;
  _userImageContainer.layer.cornerRadius = cornerRadius;
  _userImageView.layer.cornerRadius = cornerRadius;
  _userImageView.layer.masksToBounds = YES;
  
  // Set a gradient background for the user cell.
  CAGradientLayer *userGradientLayer = [CAGradientLayer layer];
  userGradientLayer.frame = CGRectMake(0, -_userCell.frame.origin.y,
                                       _userCell.bounds.size.width,
                                       _userCell.bounds.size.height + _userCell.frame.origin.y);
  userGradientLayer.colors = WKRadicalGradient();
  [_userCell.layer insertSublayer:userGradientLayer atIndex:0];
  _userCell.layer.masksToBounds = NO;
  
  // Try to remove the separators from the user cell.
  for (UIView *subview in _userCell.contentView.superview.subviews) {
    CGRect frame = subview.frame;
    if (frame.origin.x == 0 && frame.origin.y == 0 && frame.size.height < 1.f) {
      [subview removeFromSuperview];
      break;
    }
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [self updateUserInfo];
  [self updateLessonAndReviewCounts];
  [_localCachingClient sync];
  
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)clientStateChanged:(NSNotification *)notification {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    int pendingProgress = _localCachingClient.pendingProgress;
    int pendingStudyMaterials = _localCachingClient.pendingStudyMaterials;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (pendingProgress == 0 && pendingStudyMaterials == 0) {
        _queuedItemsLabel.text = @"You're up to date!";
        _queuedItemsSubtitleLabel.text = nil;
        return;
      }
      NSMutableArray<NSString *> *sections = [NSMutableArray array];
      if (pendingProgress != 0) {
        [sections addObject:[NSString stringWithFormat:@"%d review progress",
                             pendingProgress]];
      }
      if (pendingStudyMaterials != 0) {
        [sections addObject:[NSString stringWithFormat:@"%d study material updates",
                             pendingStudyMaterials]];
      }
      _queuedItemsLabel.text = [sections componentsJoinedByString:@", "];
      _queuedItemsSubtitleLabel.text = @"These will be uploaded when you're back online";
    });
  });

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
  _userLevelLabel.text = [NSString stringWithFormat:@"Level %d \u00B7 started %@",
                          user.level,
                          [user.startedAtDate timeAgoSinceNow:[NSDate date]]];
}

- (void)updateLessonAndReviewCounts {
  __weak MainViewController *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSArray<WKAssignment *> *assignments = [_localCachingClient getAllAssignments];
    int lessons = 0;
    int reviews = 0;
    
    NSDate *now = [NSDate date];
    
    NSMutableArray<NSNumber *> *upcomingReviews = [NSMutableArray arrayWithCapacity:48];
    for (int i = 0; i < 24; i++) {
      [upcomingReviews addObject:@(0)];
    }
    
    for (WKAssignment *assignment in assignments) {
      if (assignment.isLessonStage) {
        lessons ++;
      } else if (assignment.isReviewStage) {
        NSTimeInterval availableInSeconds = [assignment.availableAtDate timeIntervalSinceDate:now];
        if (availableInSeconds <= 0) {
          reviews ++;
          continue;
        }
        int availableInHours = availableInSeconds / (60 * 60);
        if (availableInHours < upcomingReviews.count) {
          [upcomingReviews setObject:[NSNumber numberWithInt:[upcomingReviews[availableInHours] intValue] + 1]
                  atIndexedSubscript:availableInHours];
        }
      }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf updateLessonCount:lessons reviewCount:reviews upcomingReviews:upcomingReviews atDate:now];
    });
  });
}

- (void)updateLessonCount:(int)lessonCount
              reviewCount:(int)reviewCount
          upcomingReviews:(NSArray<NSNumber *> *)upcomingReviews
                   atDate:(NSDate *)date {
  SetTableViewCellCount(self.lessonsCell, lessonCount);
  SetTableViewCellCount(self.reviewsCell, reviewCount);
  [_chartController update:upcomingReviews currentReviewCount:reviewCount atDate:date];
  [self updateAppIconBadgeCount:reviewCount upcomingReviews:upcomingReviews atDate:date];
}

- (void)updateAppIconBadgeCount:(int)reviewCount
                upcomingReviews:(NSArray<NSNumber *> *)upcomingReviews
                         atDate:(NSDate *)date {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  void(^updateBlock)(void) = ^() {
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:reviewCount];
    [center removeAllPendingNotificationRequests];
    
    NSDate *startDate = [[NSCalendar currentCalendar] nextDateAfterDate:date
                                                           matchingUnit:NSCalendarUnitMinute
                                                                  value:0
                                                                options:NSCalendarMatchNextTime];
    NSTimeInterval startInterval = [startDate timeIntervalSinceNow];
    int cumulativeReviews = reviewCount;
    for (int hour = 0; hour < upcomingReviews.count; hour++) {
      int reviews = [upcomingReviews[hour] intValue];
      if (reviews == 0) {
        continue;
      }
      cumulativeReviews += reviews;
      
      NSTimeInterval triggerTimeInterval = startInterval + (hour * 60 * 60);
      NSString *identifier = [NSString stringWithFormat:@"badge-%d", hour];
      UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
      content.badge = @(cumulativeReviews);
      UNNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:triggerTimeInterval repeats:NO];
      UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
      [center addNotificationRequest:request withCompletionHandler:nil];
    }
  };
  
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge)
                        completionHandler:^(BOOL granted, NSError * _Nullable error) {
                          if (!granted) {
                            return;
                          }
                          dispatch_async(dispatch_get_main_queue(), updateBlock);
                        }];
}

- (void)didPullToRefresh {
  [self.refreshControl endRefreshing];
  if (!_reachability.isReachable) {
    return;
  }
  [self updateLessonAndReviewCounts];
  [_localCachingClient sync];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"startReview"]) {
    ReviewViewController *vc = (ReviewViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    
    NSArray<WKAssignment *> *assignments = [_localCachingClient getAllAssignments];
    NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForReview:assignments];
    vc.items = items;
  } else if ([segue.identifier isEqualToString:@"startLessons"]) {
    LessonsViewController *vc = (LessonsViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    
    NSArray<WKAssignment *> *assignments = [_localCachingClient getAllAssignments];
    NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForLesson:assignments];
    if (items.count > kItemsPerLesson) {
      items = [items subarrayWithRange:NSMakeRange(0, kItemsPerLesson)];
    }
    vc.items = items;
  }
}

@end
