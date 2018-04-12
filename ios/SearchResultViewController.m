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

@interface SearchResultViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation SearchResultViewController {
  NSArray<WKSubject *> *_allSubjects;
  NSArray<WKSubject *> *_results;
  dispatch_queue_t _queue;
}

- (void)viewDidLoad {
  _queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
  dispatch_async(_queue, ^{
    @synchronized(self) {
      [self ensureAllSubjectsLoaded];
    }
  });
  
  [super viewDidLoad];
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
}

- (void)ensureAllSubjectsLoaded {
  if (_allSubjects == nil) {
    _allSubjects = [_dataLoader loadAllSubjects];
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  _allSubjects = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  _allSubjects = nil;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
  NSString *query = [searchController.searchBar.text lowercaseString];
  dispatch_async(_queue, ^{
    NSString *kanaQuery = WKConvertKanaText(query);
    NSMutableArray<WKSubject *> *results = [NSMutableArray array];
    
    @synchronized(self) {
      [self ensureAllSubjectsLoaded];
      for (WKSubject *subject in _allSubjects) {
        if (SubjectMatchesQuery(subject, query, kanaQuery)) {
          [results addObject:subject];
        }
        if (results.count > kMaxResults) {
          break;
        }
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

#pragma mark - UITableViewDataSource

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

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [_delegate searchResultSelected:_results[indexPath.row]];
}

@end
