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

static const int kUpcomingReviewsSection = 2;

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
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;

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
  
  UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"launch_screen"]];
  backgroundView.alpha = 0.25;
  self.tableView.backgroundView = backgroundView;
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(availableItemsChanged)
             name:kLocalCachingClientAvailableItemsChangedNotification
           object:_localCachingClient];
  [nc addObserver:self
         selector:@selector(pendingItemsChanged)
             name:kLocalCachingClientPendingItemsChangedNotification
           object:_localCachingClient];
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
  [self refresh];
  
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == kUpcomingReviewsSection) {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 360 : 120;
  }
  
  return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (void)refresh {
  [self updateUserInfo];
  [self updatePendingItems];
  [self updateAvailableItems];
  [_localCachingClient sync:nil];
}

- (void)pendingItemsChanged {
  if (self.view.window) {
    [self updatePendingItems];
  }
}

- (void)updatePendingItems {
  int pendingProgress = _localCachingClient.pendingProgress;
  int pendingStudyMaterials = _localCachingClient.pendingStudyMaterials;
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
}

- (void)availableItemsChanged {
  if (self.view.window) {
    [self updateAvailableItems];
  }
}

- (void)updateAvailableItems {
  int lessons = _localCachingClient.availableLessonCount;
  int reviews = _localCachingClient.availableReviewCount;
  NSArray<NSNumber *> *upcomingReviews = _localCachingClient.upcomingReviews;

  SetTableViewCellCount(self.lessonsCell, lessons);
  SetTableViewCellCount(self.reviewsCell, reviews);
  [_chartController update:upcomingReviews currentReviewCount:reviews atDate:[NSDate date]];
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

- (void)didPullToRefresh {
  [self.refreshControl endRefreshing];
  [_localCachingClient sync:nil];
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
    items = [items sortedArrayUsingSelector:@selector(compareForLessons:)];
    if (items.count > kItemsPerLesson) {
      items = [items subarrayWithRange:NSMakeRange(0, kItemsPerLesson)];
    }
    vc.items = items;
  }
}

@end
