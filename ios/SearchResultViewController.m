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

#import "SearchResultViewController.h"

#import "SubjectDetailsViewController.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"
#import "proto/Wanikani.pbobjc.h"

static const int kMaxResults = 50;

static bool SubjectMatchesQuery(TKMSubject *subject, NSString *query, NSString *kanaQuery) {
  if ([subject.japanese hasPrefix:query]) {
    return true;
  }
  for (TKMMeaning *meaning in subject.meaningsArray) {
    if ([[meaning.meaning lowercaseString] hasPrefix:query]) {
      return true;
    }
  }
  for (TKMReading *reading in subject.readingsArray) {
    if ([reading.reading hasPrefix:kanaQuery]) {
      return true;
    }
  }
  return false;
}

static bool SubjectMatchesQueryExactly(TKMSubject *subject, NSString *query, NSString *kanaQuery) {
  for (TKMMeaning *meaning in subject.meaningsArray) {
    if ([[meaning.meaning lowercaseString] isEqualToString:query]) {
      return true;
    }
  }
  for (TKMReading *reading in subject.readingsArray) {
    if ([reading.reading isEqualToString:kanaQuery]) {
      return true;
    }
  }
  return false;
}

@interface SearchResultViewController () <TKMSubjectDelegate>

@end

@implementation SearchResultViewController {
  TKMServices *_services;
  __weak id<SearchResultViewControllerDelegate> _delegate;

  NSArray<TKMSubject *> *_allSubjects;
  TKMTableModel *_model;
  dispatch_queue_t _queue;
}

- (void)setupWithServices:(id)services delegate:(id<SearchResultViewControllerDelegate>)delegate {
  _services = services;
  _delegate = delegate;
}

- (void)viewDidLoad {
  _queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
  dispatch_async(_queue, ^{
    @synchronized(self) {
      [self ensureAllSubjectsLoaded];
    }
  });

  [super viewDidLoad];
}

- (void)ensureAllSubjectsLoaded {
  if (_allSubjects == nil) {
    _allSubjects = [_services.dataLoader loadAll];
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
    NSString *kanaQuery = [KanaInput convertKanaTextWithInput:query];

    NSMutableArray<TKMSubject *> *results = [NSMutableArray array];
    @synchronized(self) {
      [self ensureAllSubjectsLoaded];
      for (TKMSubject *subject in _allSubjects) {
        if (SubjectMatchesQuery(subject, query, kanaQuery)) {
          [results addObject:subject];
        }
        if (results.count >= kMaxResults) {
          break;
        }
      }
    }
    [results sortUsingComparator:^NSComparisonResult(TKMSubject *a, TKMSubject *b) {
      bool aMatchesExactly = SubjectMatchesQueryExactly(a, query, kanaQuery);
      bool bMatchesExactly = SubjectMatchesQueryExactly(b, query, kanaQuery);
      if (aMatchesExactly && !bMatchesExactly) {
        return NSOrderedAscending;
      }
      if (bMatchesExactly && !aMatchesExactly) {
        return NSOrderedDescending;
      }
      if (a.level < b.level) {
        return NSOrderedAscending;
      }
      if (a.level > b.level) {
        return NSOrderedDescending;
      }
      return NSOrderedSame;
    }];

    dispatch_async(dispatch_get_main_queue(), ^{
      // If the query text changed since we started, don't update the list.
      NSString *newQuery = [searchController.searchBar.text lowercaseString];
      if (![query isEqual:newQuery]) {
        return;
      }

      TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];
      [model addSection];
      for (TKMSubject *subject in results) {
        [model addItem:[[TKMSubjectModelItem alloc] initWithSubject:subject
                                                           services:_services
                                                           delegate:self]];
      }
      _model = model;
      [self.tableView reloadData];
    });
  });
}

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  [_delegate searchResultSelected:subject];
}

@end
