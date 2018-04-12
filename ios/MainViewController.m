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

#import "CurrentLevelChartController.h"
#import "LessonsViewController.h"
#import "NSDate+TimeAgo.h"
#import "NSString+MD5.h"
#import "ReviewViewController.h"
#import "SearchResultViewController.h"
#import "Style.h"
#import "SubjectDetailsViewController.h"
#import "UpcomingReviewsChartController.h"
#import "UserDefaults.h"
#import "proto/Wanikani+Convenience.h"

@class CombinedChartView;
@class PieChartView;

static const NSInteger kItemsPerLesson = 5;

static const char *kDefaultProfileImageURL = "https://cdn.wanikani.com/default-avatar-300x300-20121121.png";
static const int kProfileImageSize = 80;

static const int kUpcomingReviewsSection = 1;

static const NSTimeInterval kSearchBarAnimationDuration = 0.1f;

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


@interface MainViewController () <SearchResultViewControllerDelegate,
    UISearchControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *userContainer;
@property (weak, nonatomic) IBOutlet UIView *userImageContainer;
@property (weak, nonatomic) IBOutlet UIImageView *userImageView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userLevelLabel;
@property (weak, nonatomic) IBOutlet UIButton *searchButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;

@property (weak, nonatomic) IBOutlet UITableViewCell *lessonsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *reviewsCell;

@property (weak, nonatomic) IBOutlet UILabel *queuedItemsLabel;
@property (weak, nonatomic) IBOutlet UILabel *queuedItemsSubtitleLabel;

@property (weak, nonatomic) IBOutlet CombinedChartView *upcomingReviewsChartView;
@property (weak, nonatomic) IBOutlet PieChartView *currentLevelRadicalsPieChartView;
@property (weak, nonatomic) IBOutlet PieChartView *currentLevelKanjiPieChartView;
@property (weak, nonatomic) IBOutlet PieChartView *currentLevelVocabularyPieChartView;

@end

@implementation MainViewController {
  UpcomingReviewsChartController *_upcomingReviewsChartController;
  CurrentLevelChartController *_currentLevelRadicalsChartController;
  CurrentLevelChartController *_currentLevelKanjiChartController;
  CurrentLevelChartController *_currentLevelVocabularyChartController;
  UISearchController *_searchController;
  __weak SearchResultViewController *_searchResultsViewController;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  // Show a background image.
  UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"launch_screen"]];
  backgroundView.alpha = 0.25;
  self.tableView.backgroundView = backgroundView;
  
  // Add a refresh control for when the user pulls down.
  self.refreshControl = [[UIRefreshControl alloc] init];
  self.refreshControl.tintColor = [UIColor darkGrayColor];
  self.refreshControl.backgroundColor = nil;
  NSAttributedString *title = [[NSAttributedString alloc] initWithString:@"Pull to refresh..."];
  self.refreshControl.attributedTitle = title;
  [self.refreshControl addTarget:self
                          action:@selector(didPullToRefresh)
                forControlEvents:UIControlEventValueChanged];
  
  // Create the search results view controller.
  SearchResultViewController *searchResultsViewController =
      [self.storyboard instantiateViewControllerWithIdentifier:@"searchResults"];
  searchResultsViewController.dataLoader = _dataLoader;
  searchResultsViewController.delegate = self;
  _searchResultsViewController = searchResultsViewController;
  
  // Create the search controller.
  _searchController = [[UISearchController alloc] initWithSearchResultsController:searchResultsViewController];
  _searchController.searchResultsUpdater = searchResultsViewController;
  _searchController.delegate = self;
  
  // Configure the search bar.
  UISearchBar *searchBar = _searchController.searchBar;
  searchBar.barTintColor = WKRadicalColor2();
  searchBar.tintColor = [UIColor whiteColor];
  searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  
  // Add shadows to things in the user info view.
  WKAddShadowToView(_userImageContainer, 2, 0.4, 4);
  WKAddShadowToView(_userNameLabel, 1, 0.4, 4);
  WKAddShadowToView(_userLevelLabel, 1, 0.2, 2);
  
  _upcomingReviewsChartController =
      [[UpcomingReviewsChartController alloc] initWithChartView:_upcomingReviewsChartView];
  _currentLevelRadicalsChartController =
      [[CurrentLevelChartController alloc] initWithChartView:_currentLevelRadicalsPieChartView
                                                 subjectType:WKSubject_Type_Radical
                                                  dataLoader:_dataLoader];
  _currentLevelKanjiChartController =
      [[CurrentLevelChartController alloc] initWithChartView:_currentLevelKanjiPieChartView
                                                 subjectType:WKSubject_Type_Kanji
                                                  dataLoader:_dataLoader];
  _currentLevelVocabularyChartController =
      [[CurrentLevelChartController alloc] initWithChartView:_currentLevelVocabularyPieChartView
                                                 subjectType:WKSubject_Type_Vocabulary
                                                  dataLoader:_dataLoader];
  
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
  CGRect userGradientFrame = _userContainer.bounds;
  CGFloat yModifier = self.tableView.bounds.origin.y;
  userGradientFrame.origin.y += yModifier;
  userGradientFrame.size.height -= yModifier;
  
  CAGradientLayer *userGradientLayer = [CAGradientLayer layer];
  userGradientLayer.frame = userGradientFrame;
  userGradientLayer.colors = WKRadicalGradient();
  [_userContainer.layer insertSublayer:userGradientLayer atIndex:0];
  _userContainer.layer.masksToBounds = NO;
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
  NSArray<WKAssignment *> *maxLevelAssignments = _localCachingClient.maxLevelAssignments;

  SetTableViewCellCount(self.lessonsCell, lessons);
  SetTableViewCellCount(self.reviewsCell, reviews);
  [_upcomingReviewsChartController update:upcomingReviews currentReviewCount:reviews atDate:[NSDate date]];
  [_currentLevelRadicalsChartController update:maxLevelAssignments];
  [_currentLevelKanjiChartController update:maxLevelAssignments];
  [_currentLevelVocabularyChartController update:maxLevelAssignments];
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

- (IBAction)didTapSearchButton:(id)sender {
  [self presentViewController:_searchController animated:YES completion:nil];
}

- (void)searchResultSelected:(WKSubject *)subject {
  SubjectDetailsViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  vc.showUserProgress = true;
  vc.dataLoader = _dataLoader;
  vc.localCachingClient = _localCachingClient;
  vc.subject = subject;
  [_searchController dismissViewControllerAnimated:YES completion:^{
    [self.navigationController pushViewController:vc animated:YES];
  }];
}

@end
