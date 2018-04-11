#import "SearchResultViewController.h"

#import "DataLoader.h"
#import "ReviewSummaryCell.h"
#import "SubjectDetailsViewController.h"
#import "WKKanaInput.h"
#import "proto/Wanikani.pbobjc.h"

static const int kMaxResults = 50;

static bool SubjectMatchesQuery(WKSubject *subject, NSString *query, NSString *kanaQuery) {
  for (WKMeaning *meaning in subject.meaningsArray) {
    if ([[meaning.meaning lowercaseString] hasPrefix:query]) {
      return true;
    }
  }
  for (WKReading *reading in subject.readingsArray) {
    if ([reading.reading hasPrefix:kanaQuery]) {
      return true;
    }
  }
  return false;
}

static bool SubjectMatchesQueryExactly(WKSubject *subject, NSString *query, NSString *kanaQuery) {
  for (WKMeaning *meaning in subject.meaningsArray) {
    if ([[meaning.meaning lowercaseString] isEqualToString:query]) {
      return true;
    }
  }
  for (WKReading *reading in subject.readingsArray) {
    if ([reading.reading isEqualToString:kanaQuery]) {
      return true;
    }
  }
  return false;
}

@interface SearchResultViewController () <UITableViewDataSource>

@end

@implementation SearchResultViewController {
  NSArray<WKSubject *> *_subjects;
  NSArray<WKSubject *> *_results;
  dispatch_queue_t _queue;
}

- (void)viewDidLoad {
  _queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
  dispatch_async(_queue, ^{
    _subjects = [_dataLoader loadAllSubjects];
  });
  
  [super viewDidLoad];
  self.tableView.dataSource = self;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
  NSString *query = [searchController.searchBar.text lowercaseString];
  dispatch_async(_queue, ^{
    NSString *kanaQuery = WKConvertKanaText(query);
    NSMutableArray<WKSubject *> *results = [NSMutableArray array];
    for (WKSubject *subject in _subjects) {
      if (SubjectMatchesQuery(subject, query, kanaQuery)) {
        [results addObject:subject];
      }
      if (results.count > kMaxResults) {
        break;
      }
    }
    [results sortUsingComparator:^NSComparisonResult(WKSubject *a, WKSubject *b) {
      bool aMatchesExactly = SubjectMatchesQueryExactly(a, query, kanaQuery);
      bool bMatchesExactly = SubjectMatchesQueryExactly(b, query, kanaQuery);
      if (aMatchesExactly && !bMatchesExactly) { return NSOrderedAscending; }
      if (bMatchesExactly && !aMatchesExactly) { return NSOrderedDescending; }
      if (a.level < b.level) { return NSOrderedAscending; }
      if (a.level > b.level) { return NSOrderedDescending; }
      return NSOrderedSame;
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      _results = results;
      [self.tableView reloadData];
    });
  });
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  ReviewSummaryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resultCell"];
  WKSubject *subject = _results[indexPath.row];
  cell.subject = subject;
  return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"resultDetails"]) {
    ReviewSummaryCell *cell = (ReviewSummaryCell *)sender;
    SubjectDetailsViewController *vc = (SubjectDetailsViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    vc.subject = cell.subject;
  }
}

@end
