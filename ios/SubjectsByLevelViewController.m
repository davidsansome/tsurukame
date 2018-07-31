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

#import "SubjectsByLevelViewController.h"

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "proto/Wanikani+Convenience.h"
#import "Style.h"
#import "SubjectDetailsViewController.h"
#import "Tables/TKMListSeparatorItem.h"
#import "Tables/TKMModelItem.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"

@interface SubjectsByLevelViewController () <TKMSubjectDelegate>
@end

@implementation SubjectsByLevelViewController {
  TKMTableModel *_model;
  UISwitch *_answerSwitch;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _answerSwitch = [[UISwitch alloc] init];
  _answerSwitch.on = YES;
  [_answerSwitch addTarget:self
                    action:@selector(answerSwitchChanged:)
          forControlEvents:UIControlEventValueChanged];
  
  self.navigationItem.title = [NSString stringWithFormat:@"Level %d", _level];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_answerSwitch];
  
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];
  [model addSection:@"Radicals"];
  [model addSection:@"Kanji"];
  [model addSection:@"Vocabulary"];
  
  for (TKMAssignment *assignment in [_localCachingClient getAssignmentsAtLevel:_level]) {
    TKMSubject *subject = [_dataLoader loadSubject:assignment.subjectId];
    int section = subject.subjectType - 1;
    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                  assignment:assignment
                                                                    delegate:self];
    item.showLevelNumber = false;
    if (!assignment.isReviewStage && !assignment.isLessonStage) {
      item.gradientColors = TKMLockedGradient();
    }
    [model addItem:item toSection:section];
  }
  
  NSComparator comparator = ^NSComparisonResult(TKMSubjectModelItem *a, TKMSubjectModelItem *b) {
    if (a.assignment.isReviewStage && !b.assignment.isReviewStage) return NSOrderedAscending;
    if (!a.assignment.isReviewStage && b.assignment.isReviewStage) return NSOrderedDescending;
    if (a.assignment.isLessonStage && !b.assignment.isLessonStage) return NSOrderedAscending;
    if (!a.assignment.isLessonStage && b.assignment.isLessonStage) return NSOrderedDescending;
    if (a.assignment.srsStage < b.assignment.srsStage) return NSOrderedAscending;
    if (a.assignment.srsStage > b.assignment.srsStage) return NSOrderedDescending;
    return NSOrderedSame;
  };
  [model sortSection:0 usingComparator:comparator];
  [model sortSection:1 usingComparator:comparator];
  [model sortSection:2 usingComparator:comparator];
  
  for (int section = 0; section < model.sectionCount; ++section) {
    NSArray *items = [model itemsInSection:section];
    TKMAssignment *lastAssignment = nil;
    for (int index = 0; index < items.count; ++index) {
      TKMAssignment *assignment = ((TKMSubjectModelItem *) items[index]).assignment;
      if (lastAssignment == nil ||
          lastAssignment.srsStage != assignment.srsStage ||
          lastAssignment.isReviewStage != assignment.isReviewStage ||
          lastAssignment.isLessonStage != assignment.isLessonStage) {
        NSString *label;
        if (assignment.isReviewStage) {
          label = TKMDetailedSRSStageName(assignment.srsStage);
        } else if (assignment.isLessonStage) {
          label = @"Available in Lessons";
        } else {
          label = @"Locked";
        }
        [model insertItem:[[TKMListSeparatorItem alloc] initWithLabel:label] atIndex:index inSection:section];
        index ++;
      }
      lastAssignment = assignment;
    }
  }
  
  _model = model;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

- (void)answerSwitchChanged:(UISwitch *)sender {
  bool showAnswers = sender.on;
  
  for (int section = 0; section < _model.sectionCount; ++section) {
    for (id<TKMModelItem> item in [_model itemsInSection:section]) {
      if ([item isKindOfClass:TKMSubjectModelItem.class]) {
        TKMSubjectModelItem *subjectItem = item;
        subjectItem.showAnswers = showAnswers;
      }
    }
  }
  
  for (UITableViewCell *cell in self.tableView.visibleCells) {
    if ([cell isKindOfClass:TKMSubjectModelView.class]) {
      TKMSubjectModelView *subjectCell = (TKMSubjectModelView *)cell;
      [subjectCell setShowAnswers:showAnswers animated:true];
    }
  }
}

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  vc.dataLoader = _dataLoader;
  vc.localCachingClient = _localCachingClient;
  vc.subject = subject;
  [self.navigationController pushViewController:vc animated:YES];
}

@end
