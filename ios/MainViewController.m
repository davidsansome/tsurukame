#import "MainViewController.h"

#import "LessonsViewController.h"
#import "NSDate+TimeAgo.h"
#import "NSString+MD5.h"
#import "ReviewViewController.h"
#import "Style.h"
#import "UpcomingReviewsChartController.h"
#import "UserDefaults.h"
#import "proto/Wanikani+Convenience.h"

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


@interface MainViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *userCell;
@property (weak, nonatomic) IBOutlet UIView *userImageContainer;
@property (weak, nonatomic) IBOutlet UIImageView *userImageView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userLevelLabel;

@property (weak, nonatomic) IBOutlet UITableViewCell *lessonsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *reviewsCell;

@property (weak, nonatomic) IBOutlet CombinedChartView *upcomingReviewsChartView;

@end

@implementation MainViewController {
  UpcomingReviewsChartController *_chartController;
}

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
  
  WKAddShadowToView(_userImageContainer, 2, 0.4, 4);
  WKAddShadowToView(_userNameLabel, 1, 0.4, 4);
  WKAddShadowToView(_userLevelLabel, 1, 0.2, 2);
  
  _chartController =
      [[UpcomingReviewsChartController alloc] initWithChartView:_upcomingReviewsChartView];
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
  [_localCachingClient update];
  
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
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
  _userLevelLabel.text = [NSString stringWithFormat:@"Level %d \u00B7 started %@",
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
    
    [_chartController update:upcomingReviews currentReviewCount:reviewCount];
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
