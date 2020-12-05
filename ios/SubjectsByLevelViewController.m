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

#import "Extensions/ProtobufExtensions.h"
#import "SubjectDetailsViewController.h"
#import "Tables/TKMListSeparatorItem.h"
#import "Tables/TKMModelItem.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"

@interface SubjectsByLevelViewController () <TKMSubjectDelegate>
@end

@implementation SubjectsByLevelViewController {
  TKMServices *_services;
  int _level;
  TKMTableModel *_model;
}

- (void)setupWithServices:(TKMServices *)services level:(int)level showAnswers:(bool)showAnswers {
  _services = services;
  _level = level;
  [self setShowAnswers:showAnswers animated:NO];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.title = [NSString stringWithFormat:@"Level %d", _level];

  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];
  [model addSection:@"Radicals"];
  [model addSection:@"Kanji"];
  [model addSection:@"Vocabulary"];

  for (TKMAssignment *assignment in [_services.localCachingClient getAssignmentsWithLevel:_level]) {
    TKMSubject *subject = [_services.dataLoader loadSubject:assignment.subjectId];
    if (!subject) {
      continue;
    }

    int section = subject.subjectType - 1;
    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                  assignment:assignment
                                                                    delegate:self];
    item.showLevelNumber = false;
    item.showAnswers = _showAnswers;
    if (assignment.isLocked || assignment.isBurned) {
      item.gradientColors = TKMStyle.lockedGradient;
    }
    [model addItem:item toSection:section];
  }

  NSComparator comparator = ^NSComparisonResult(TKMSubjectModelItem *a, TKMSubjectModelItem *b) {
    if (a.assignment.isLocked && !b.assignment.isLocked) return NSOrderedDescending;
    if (!a.assignment.isLocked && b.assignment.isLocked) return NSOrderedAscending;
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
      TKMAssignment *assignment = ((TKMSubjectModelItem *)items[index]).assignment;
      if (lastAssignment == nil || lastAssignment.srsStage != assignment.srsStage ||
          lastAssignment.isReviewStage != assignment.isReviewStage ||
          lastAssignment.isLessonStage != assignment.isLessonStage) {
        NSString *label;
        if (assignment.isLocked) {
          label = @"Locked";
        } else if (assignment.isLessonStage) {
          label = @"Available in Lessons";
        } else {
          label = TKMDetailedSRSStageName(assignment.srsStage);
        }
        [model insertItem:[[TKMListSeparatorItem alloc] initWithLabel:label]
                  atIndex:index
                inSection:section];
        index++;
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

- (void)setShowAnswers:(bool)showAnswers {
  [self setShowAnswers:showAnswers animated:false];
}

- (void)setShowAnswers:(bool)showAnswers animated:(bool)animated {
  _showAnswers = showAnswers;
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
      [subjectCell setShowAnswers:showAnswers animated:animated];
    }
  }
}

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  [vc setupWithServices:_services subject:subject];
  [self.navigationController pushViewController:vc animated:YES];
}

@end
