#import "MainViewController.h"
#import "ReviewViewController.h"

@interface MainViewController ()
@property (weak, nonatomic) IBOutlet UILabel *syncTitle;
@property (weak, nonatomic) IBOutlet UILabel *syncSubtitle;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *syncSpinner;
@property (weak, nonatomic) IBOutlet UIImageView *syncOfflineImage;

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

- (void)viewWillAppear:(BOOL)animated {
  [self updateSyncState];
  [super viewWillAppear:animated];
}

- (void)reachabilityChanged:(NSNotification *)notification {
  [self updateSyncState];
}

- (void)clientBusyChanged:(NSNotification *)notification {
  [self updateSyncState];
}

- (void)updateSyncState {
  if (!_reachability.isReachable) {
    self.syncTitle.text = @"No internet connection";
    self.syncSubtitle.text = @"Your progress will be synced when you're back online";
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
    self.syncSubtitle.text = @"Your progress, synonyms and notes are synced to this device";
    [self.syncSubtitle setHidden:NO];
    [self.syncSpinner stopAnimating];
    [self.syncOfflineImage setHidden:YES];
  }
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
