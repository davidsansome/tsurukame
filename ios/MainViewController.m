// Copyright 2018 David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "MainViewController.h"

#import "LessonsViewController.h"
#import "LocalCachingClient.h"
#import "LoginViewController.h"
#import "NSDate+TimeAgo.h"
#import "NSString+MD5.h"
#import "ReviewItem.h"
#import "SearchResultViewController.h"
#import "Settings.h"
#import "SettingsViewController.h"
#import "SubjectCatalogueViewController.h"
#import "SubjectDetailsViewController.h"
#import "SubjectsRemainingViewController.h"
#import "TKMReviewContainerViewController.h"
#import "TKMServices.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"
#import "proto/Wanikani+Convenience.h"

#import <Haneke/Haneke.h>

@class CombinedChartView;
@class PieChartView;

static const char *kDefaultProfileImageURL =
    "https://cdn.wanikani.com/default-avatar-300x300-20121121.png";
static const int kProfileImageSize = 80;

static const int kUpcomingReviewsSection = 1;

static const CGFloat kUserGradientYOffset = 450;
static const CGFloat kUserGradientStartPoint = 0.8f;

static NSURL *UserProfileImageURL(NSString *emailAddress) {
  emailAddress =
      [emailAddress stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  emailAddress = [emailAddress lowercaseString];
  NSString *hash = [emailAddress MD5];

  int size = kProfileImageSize * [[UIScreen mainScreen] scale];

  return [NSURL
      URLWithString:[NSString stringWithFormat:@"https://www.gravatar.com/avatar/%@.jpg?s=%d&d=%s",
                                               hash, size, kDefaultProfileImageURL]];
}

static BOOL SetTableViewCellCount(TKMBasicModelItem *item, int count) {
  item.subtitle = (count < 0) ? @"-" : [@(count) stringValue];
  item.enabled = count > 0;
  return item.enabled;
}

@interface MainViewController () <LoginViewControllerDelegate,
                                  SearchResultViewControllerDelegate,
                                  UISearchControllerDelegate>

@property(weak, nonatomic) IBOutlet UIView *userContainer;
@property(weak, nonatomic) IBOutlet UIView *userImageContainer;
@property(weak, nonatomic) IBOutlet UIImageView *userImageView;
@property(weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property(weak, nonatomic) IBOutlet UILabel *userLevelLabel;
@property(weak, nonatomic) IBOutlet UIButton *searchButton;
@property(weak, nonatomic) IBOutlet UIButton *settingsButton;

@end

@implementation MainViewController {
  TKMServices *_services;
  TKMTableModel *_model;
  UISearchController *_searchController;
  __weak SearchResultViewController *_searchResultsViewController;
  __weak CAGradientLayer *_userGradientLayer;
  NSTimer *_hourlyRefreshTimer;
  BOOL _isShowingUnauthorizedAlert;
  BOOL _hasLessons;
  BOOL _hasReviews;
  BOOL _updatingTableModel;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Show a background image.
  UIImageView *backgroundView =
      [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"launch_screen"]];
  backgroundView.alpha = 0.25;
  self.tableView.backgroundView = backgroundView;

  // Add a refresh control for when the user pulls down.
  self.refreshControl = [[UIRefreshControl alloc] init];
  self.refreshControl.tintColor = [UIColor labelColor];
  self.refreshControl.backgroundColor = nil;
  NSMutableAttributedString *title = [[NSMutableAttributedString alloc]
      initWithString:@"Pull to refresh..."
          attributes:@{NSForegroundColorAttributeName : [UIColor labelColor]}];
  self.refreshControl.attributedTitle = title;
  [self.refreshControl addTarget:self
                          action:@selector(didPullToRefresh)
                forControlEvents:UIControlEventValueChanged];

  // Set a gradient background for the user cell.
  CAGradientLayer *userGradientLayer = [CAGradientLayer layer];
  userGradientLayer.colors = TKMStyle.radicalGradient;
  userGradientLayer.startPoint = CGPointMake(0.5f, kUserGradientStartPoint);
  [_userContainer.layer insertSublayer:userGradientLayer atIndex:0];
  _userGradientLayer = userGradientLayer;
  _userContainer.layer.masksToBounds = NO;

  // Create the search results view controller.
  SearchResultViewController *searchResultsViewController =
      [self.storyboard instantiateViewControllerWithIdentifier:@"searchResults"];
  [searchResultsViewController setupWithServices:_services delegate:self];
  _searchResultsViewController = searchResultsViewController;

  // Create the search controller.
  _searchController =
      [[UISearchController alloc] initWithSearchResultsController:searchResultsViewController];
  _searchController.searchResultsUpdater = searchResultsViewController;
  _searchController.delegate = self;

  // Configure the search bar.
  UISearchBar *searchBar = _searchController.searchBar;
  searchBar.barTintColor = TKMStyle.radicalColor2;
  searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;

  UIColor *originalSearchBarTintColor = searchBar.tintColor;
  searchBar.tintColor = [UIColor labelColor];  // Make the button white.

  if (@available(iOS 13, *)) {
    UITextField *searchTextField = searchBar.searchTextField;
    searchTextField.backgroundColor = [UIColor systemBackgroundColor];
    searchTextField.tintColor = originalSearchBarTintColor;
  } else {
    for (UIView *view in _searchController.searchBar.subviews.firstObject.subviews) {
      if ([view isKindOfClass:UITextField.class]) {
        view.tintColor = originalSearchBarTintColor;  // Make the input field cursor dark blue.
      }
    }
  }

  // Add shadows to things in the user info view.
  [TKMStyle addShadowToView:_userImageContainer offset:2.f opacity:0.4f radius:4.f];
  [TKMStyle addShadowToView:_userNameLabel offset:1.f opacity:0.4f radius:4.f];
  [TKMStyle addShadowToView:_userLevelLabel offset:1.f opacity:0.2f radius:2.f];

  // Set rounded corners on the user image.
  CGFloat cornerRadius = _userImageContainer.bounds.size.height / 2;
  _userImageContainer.layer.cornerRadius = cornerRadius;
  _userImageView.layer.cornerRadius = cornerRadius;
  _userImageView.layer.masksToBounds = YES;

  [self updateHourlyTimer];

  [self recreateTableModel];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(availableItemsChanged)
             name:kLocalCachingClientAvailableItemsChangedNotification
           object:_services.localCachingClient];
  [nc addObserver:self
         selector:@selector(pendingItemsChanged)
             name:kLocalCachingClientPendingItemsChangedNotification
           object:_services.localCachingClient];
  [nc addObserver:self
         selector:@selector(userInfoChanged)
             name:kLocalCachingClientUserInfoChangedNotification
           object:_services.localCachingClient];
  [nc addObserver:self
         selector:@selector(srsLevelCountsChanged)
             name:kLocalCachingClientSrsLevelCountsChangedNotification
           object:_services.localCachingClient];
  [nc addObserver:self
         selector:@selector(clientIsUnauthorized)
             name:kLocalCachingClientUnauthorizedNotification
           object:_services.localCachingClient];
  [nc addObserver:self
         selector:@selector(applicationDidEnterBackground:)
             name:UIApplicationDidEnterBackgroundNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(applicationWillEnterForeground:)
             name:UIApplicationWillEnterForegroundNotification
           object:nil];
}

- (void)scheduleTableModelUpdate {
  if (_updatingTableModel) {
    return;
  }
  _updatingTableModel = true;
  dispatch_async(dispatch_get_main_queue(), ^{
    _updatingTableModel = false;
    [self recreateTableModel];
  });
}

- (void)recreateTableModel {
  int lessons = _services.localCachingClient.availableLessonCount;
  int reviews = _services.localCachingClient.availableReviewCount;
  NSArray<NSNumber *> *upcomingReviews = _services.localCachingClient.upcomingReviews;
  NSArray<TKMAssignment *> *currentLevelAssignments =
      [_services.localCachingClient getAssignmentsAtUsersCurrentLevel];

  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];

  [model addSection:@"Currently Available"];
  TKMBasicModelItem *lessonsItem =
      [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                         title:@"Lessons"
                                      subtitle:@""
                                 accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                        target:self
                                        action:@selector(startLessons:)];
  _hasLessons = SetTableViewCellCount(lessonsItem, lessons);
  [model addItem:lessonsItem];

  TKMBasicModelItem *reviewsItem =
      [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                         title:@"Reviews"
                                      subtitle:@""
                                 accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                        target:self
                                        action:@selector(startReviews:)];
  _hasReviews = SetTableViewCellCount(reviewsItem, reviews);
  [model addItem:reviewsItem];

  [model addSection:@"Upcoming reviews"];
  [model addItem:[[UpcomingReviewsChartItem alloc] init:upcomingReviews
                                     currentReviewCount:reviews
                                                     at:[NSDate date]]];

  [model addSection:@"This level"];
  [model addItem:[[CurrentLevelChartItem alloc] initWithDataLoader:_services.dataLoader
                                           currentLevelAssignments:currentLevelAssignments]];
  [model addItem:[[LevelTimeRemainingItem alloc] initWithServices:_services
                                          currentLevelAssignments:currentLevelAssignments]];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                 title:@"Show remaining"
                                              subtitle:nil
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(showRemaining:)]];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                 title:@"Show all"
                                              subtitle:nil
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(showAll:)]];

  [model addSection:@"All levels"];
  for (TKMSRSStageCategory stageCategory = TKMSRSStageApprentice;
       stageCategory <= TKMSRSStageBurned; ++stageCategory) {
    int count = [_services.localCachingClient getSrsLevelCount:stageCategory];
    [model addItem:[[SRSStageCategoryItem alloc] initWithStageCategory:stageCategory count:count]];
  }

  _model = model;
}

#pragma mark - UIViewController

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  [self cancelHourlyTimer];
}

- (void)viewWillAppear:(BOOL)animated {
  [self refresh];
  [self updateHourlyTimer];

  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)viewWillLayoutSubviews {
  [super viewWillLayoutSubviews];

  CGRect userGradientFrame = _userContainer.bounds;
  userGradientFrame.origin.y -= kUserGradientYOffset;
  userGradientFrame.size.height += kUserGradientYOffset;
  _userGradientLayer.frame = userGradientFrame;

  // Bring the refresh control above the gradient.
  [self.refreshControl.superview bringSubviewToFront:self.refreshControl];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"startReviews"]) {
    NSArray<TKMAssignment *> *assignments = [_services.localCachingClient getAllAssignments];
    NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForReview:assignments
                                                              dataLoader:_services.dataLoader];
    if (!items.count) {
      return;
    }

#ifdef APP_STORE_SCREENSHOTS
    items = [items subarrayWithRange:NSMakeRange(0, 32)];
#endif  // APP_STORE_SCREENSHOTS

    TKMReviewContainerViewController *vc =
        (TKMReviewContainerViewController *)segue.destinationViewController;
    [vc setupWithServices:_services items:items];
  } else if ([segue.identifier isEqualToString:@"startLessons"]) {
    NSArray<TKMAssignment *> *assignments = [_services.localCachingClient getAllAssignments];
    NSArray<ReviewItem *> *items = [ReviewItem assignmentsReadyForLesson:assignments
                                                              dataLoader:_services.dataLoader];
    if (!items.count) {
      return;
    }

    items = [items sortedArrayUsingSelector:@selector(compareForLessons:)];
    if (items.count > Settings.lessonBatchSize) {
      items = [items subarrayWithRange:NSMakeRange(0, Settings.lessonBatchSize)];
    }

    LessonsViewController *vc = (LessonsViewController *)segue.destinationViewController;
    [vc setupWithServices:_services items:items];
  } else if ([segue.identifier isEqualToString:@"showAll"]) {
    SubjectCatalogueViewController *vc =
        (SubjectCatalogueViewController *)segue.destinationViewController;
    [vc setupWithServices:_services level:_services.localCachingClient.getUserInfo.level];
  } else if ([segue.identifier isEqualToString:@"showRemaining"]) {
    SubjectsRemainingViewController *vc = segue.destinationViewController;
    [vc setupWithServices:_services];
  } else if ([segue.identifier isEqual:@"settings"]) {
    SettingsViewController *vc = (SettingsViewController *)segue.destinationViewController;
    [vc setupWithServices:_services];
  }
}

#pragma mark - UITableViewController

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == kUpcomingReviewsSection) {
    return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? 360 : 120;
  }

  return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

#pragma mark - Refresh on the hour in the foreground

- (void)updateHourlyTimer {
  [self cancelHourlyTimer];

  NSDate *date = [[NSCalendar currentCalendar] nextDateAfterDate:[NSDate date]
                                                    matchingUnit:NSCalendarUnitMinute
                                                           value:0
                                                         options:NSCalendarMatchNextTime];
  __weak MainViewController *weakSelf = self;
  _hourlyRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:[date timeIntervalSinceNow]
                                                        repeats:NO
                                                          block:^(NSTimer *_Nonnull timer) {
                                                            [weakSelf hourlyTimerExpired];
                                                          }];
}

- (void)cancelHourlyTimer {
  [_hourlyRefreshTimer invalidate];
  _hourlyRefreshTimer = nil;
}

- (void)hourlyTimerExpired {
  [self refresh];
  [self updateHourlyTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
  [self cancelHourlyTimer];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
  [self updateHourlyTimer];
}

#pragma mark - Refreshing contents

- (void)refresh {
  [self updateUserInfo];
  [self updatePendingItems];
  [self scheduleTableModelUpdate];
  [_services.localCachingClient sync:nil];
}

- (void)pendingItemsChanged {
  if (self.view.window) {
    [self updatePendingItems];
  }
}

- (void)updatePendingItems {
  // TODO: Show a progress bar.
}

- (void)availableItemsChanged {
  if (self.view.window) {
    [self scheduleTableModelUpdate];
  }
}

- (void)userInfoChanged {
  [self updateUserInfo];
}

- (void)updateUserInfo {
  TKMUser *user = [_services.localCachingClient getUserInfo];
  int guruKanji = [_services.localCachingClient getGuruKanjiCount];

  NSString *email = [Settings userEmailAddress];
  if (email.length) {
    NSURL *imageURL = UserProfileImageURL(email);
    [_userImageView hnk_setImageFromURL:imageURL];
  }

  _userNameLabel.text = user.username;
  _userLevelLabel.text =
      [NSString stringWithFormat:@"Level %d \u00B7 learned %d kanji", user.level, guruKanji];
}

- (void)srsLevelCountsChanged {
  [self updateUserInfo];
  [self scheduleTableModelUpdate];
}

- (void)clientIsUnauthorized {
  if (_isShowingUnauthorizedAlert) {
    return;
  }
  _isShowingUnauthorizedAlert = YES;
  UIAlertController *ac =
      [UIAlertController alertControllerWithTitle:@"Logged out"
                                          message:
                                              @"Your API Token expired - please log in again. "
                                               "You won't lose your review progress"
                                   preferredStyle:UIAlertControllerStyleAlert];

  __weak MainViewController *weakSelf = self;
  [ac addAction:[UIAlertAction actionWithTitle:@"OK"
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *_Nonnull action) {
                                         MainViewController *strongSelf = weakSelf;
                                         if (strongSelf) {
                                           [strongSelf loginAgain];
                                         }
                                       }]];
  [self presentViewController:ac animated:YES completion:nil];
}

- (void)loginAgain {
  LoginViewController *loginViewController =
      [self.storyboard instantiateViewControllerWithIdentifier:@"login"];
  loginViewController.delegate = self;
  loginViewController.forcedUsername = [_services.localCachingClient getUserInfo].username;
  [self.navigationController pushViewController:loginViewController animated:YES];
}

- (void)loginComplete {
  [_services.localCachingClient.client updateApiToken:Settings.userApiToken
                                               cookie:Settings.userCookie];
  [self.navigationController popViewControllerAnimated:YES];
  _isShowingUnauthorizedAlert = NO;
}

- (void)didPullToRefresh {
  [self.refreshControl endRefreshing];
  [self refresh];
}

#pragma mark - Search

- (IBAction)didTapSearchButton:(id)sender {
  [self presentViewController:_searchController animated:YES completion:nil];
}

- (void)searchResultSelected:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  [vc setupWithServices:_services subject:subject showHints:YES hideBackButton:NO index:0];
  [_searchController dismissViewControllerAnimated:YES
                                        completion:^{
                                          [self.navigationController pushViewController:vc
                                                                               animated:YES];
                                        }];
}

#pragma mark - Keyboard navigation

- (BOOL)canBecomeFirstResponder {
  return true;
}

- (void)startReviews:(id)sender {
  [self performSegueWithIdentifier:@"startReviews" sender:self];
}

- (void)startLessons:(id)sender {
  [self performSegueWithIdentifier:@"startLessons" sender:self];
}

- (void)showRemaining:(id)sender {
  [self performSegueWithIdentifier:@"showRemaining" sender:self];
}

- (void)showAll:(id)sender {
  [self performSegueWithIdentifier:@"showAll" sender:self];
}

- (NSArray<UIKeyCommand *> *)keyCommands {
  NSMutableArray<UIKeyCommand *> *keyCommands = [NSMutableArray array];

  // Press return to keep studying, first lessons then reviews
  if (_hasLessons && !_hasReviews) {
    [keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"\r"
                                               modifierFlags:0
                                                      action:@selector(startLessons:)
                                        discoverabilityTitle:@"Continue lessons"]];
  } else if (_hasReviews) {
    [keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"\r"
                                               modifierFlags:0
                                                      action:@selector(startReviews:)
                                        discoverabilityTitle:@"Continue reviews"]];
  }

  // Command L to start lessons, if any
  if (_hasLessons) {
    [keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"l"
                                               modifierFlags:UIKeyModifierCommand
                                                      action:@selector(startLessons:)
                                        discoverabilityTitle:@"Start lessons"]];
  }

  // Command R to start reviews, if any
  if (_hasReviews) {
    [keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"r"
                                               modifierFlags:UIKeyModifierCommand
                                                      action:@selector(startReviews:)
                                        discoverabilityTitle:@"Start reviews"]];
  }

  return keyCommands;
}

@end
