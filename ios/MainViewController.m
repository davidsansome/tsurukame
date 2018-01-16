#import "MainViewController.h"
#import "ReviewViewController.h"
#import "proto/Wanikani+Convenience.h"

@interface MainViewController ()
@property (weak, nonatomic) IBOutlet UILabel *syncTitle;
@property (weak, nonatomic) IBOutlet UILabel *syncSubtitle;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *syncSpinner;
@property (weak, nonatomic) IBOutlet UIImageView *syncOfflineImage;
@property (weak, nonatomic) IBOutlet UITableViewCell *lessonsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *reviewsCell;

@end

@implementation MainViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(reachabilityChanged:)
               name:kReachabilityChangedNotification
             object:_reachability];
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
}

- (void)viewWillAppear:(BOOL)animated {
  [self updateSyncState];
  [self updateLessonAndReviewCounts];
  [_localCachingClient update];
  
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (void)reachabilityChanged:(NSNotification *)notification {
  [self updateSyncState];
}

- (void)clientBusyChanged:(NSNotification *)notification {
  [self updateSyncState];
  
  // An update just finished - update the lesson and review counts.
  if (!_localCachingClient.isBusy) {
    [self updateLessonAndReviewCounts];
  }
}

- (void)updateLessonAndReviewCounts {
  __weak MainViewController *weakSelf = self;
  [_localCachingClient getAllAssignments:^(NSError *error, NSArray<WKAssignment *> *assignments) {
    if (error) {
      [weakSelf updateLessonCount:-1 reviewCount:-1];
      return;
    }
    int reviews = 0;
    for (WKAssignment *assignment in assignments) {
      if (assignment.isReadyForReview) {
        reviews ++;
      }
    }
    [weakSelf updateLessonCount:0 reviewCount:reviews];
  }];
}

- (void)updateLessonCount:(int)lessonCount reviewCount:(int)reviewCount {
  __weak MainViewController *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    weakSelf.lessonsCell.detailTextLabel.text = (lessonCount < 0) ? @"-" : [@(lessonCount) stringValue];
    weakSelf.reviewsCell.detailTextLabel.text = (reviewCount < 0) ? @"-" : [@(reviewCount) stringValue];
  });
}

- (void)updateSyncState {
  if (!_reachability.isReachable) {
    self.syncTitle.text = @"No internet connection";
    self.syncSubtitle.text = @"You can still do reviews, your progress will be synced when you're back online.";
    [self.syncSubtitle setHidden:NO];
    [self.syncSpinner stopAnimating];
    [self.syncOfflineImage setHidden:NO];
  } else if (_localCachingClient.isBusy) {
    self.syncTitle.text = @"Syncing...";
    [self.syncSubtitle setHidden:YES];
    [self.syncSpinner setHidden:NO];
    [self.syncSpinner startAnimating];
    [self.syncOfflineImage setHidden:YES];
  } else {
    self.syncTitle.text = @"Up to date!";
    self.syncSubtitle.text = [NSString stringWithFormat:@"Synced at %@",
                              [NSDateFormatter localizedStringFromDate:_localCachingClient.lastUpdated
                                                             dateStyle:NSDateFormatterNoStyle
                                                             timeStyle:NSDateFormatterMediumStyle]];
    [self.syncSubtitle setHidden:NO];
    [self.syncSpinner stopAnimating];
    [self.syncOfflineImage setHidden:YES];
  }
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
  }
}

@end
