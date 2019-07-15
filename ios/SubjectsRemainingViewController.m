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

#import "SubjectsRemainingViewController.h"

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "Style.h"
#import "SubjectDetailsViewController.h"
#import "TKMServices.h"
#import "Tables/TKMListSeparatorItem.h"
#import "Tables/TKMModelItem.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"
#import "proto/Wanikani+Convenience.h"

@interface SubjectsRemainingViewController () <TKMSubjectDelegate>
@end

@implementation SubjectsRemainingViewController {
  TKMServices *_services;
  TKMTableModel *_model;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  int level = [_services.localCachingClient getUserInfo].level;
  self.navigationItem.title = [NSString stringWithFormat:@"Remaining in Level %d", level];

  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];
  [model addSection:@"Radicals"];
  [model addSection:@"Kanji"];

  for (TKMAssignment *assignment in [_services.localCachingClient getAssignmentsAtUsersCurrentLevel]) {
    if (assignment.srsStage > 4) {
      continue;
    }

    TKMSubject *subject = [_services.dataLoader loadSubject:assignment.subjectId];
    if (!subject || subject.subjectType == TKMSubject_Type_Vocabulary) {
      continue;
    }

    int section = subject.subjectType - 1;
    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                  assignment:assignment
                                                                    delegate:self];
    item.showLevelNumber = false;
    item.showAnswers = false;
    item.showRemaining = true;
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
    if (a.assignment.srsStage > b.assignment.srsStage) return NSOrderedAscending;
    if (a.assignment.srsStage < b.assignment.srsStage) return NSOrderedDescending;
    return NSOrderedSame;
  };
  [model sortSection:0 usingComparator:comparator];
  [model sortSection:1 usingComparator:comparator];

  for (int section = 0; section < model.sectionCount; ++section) {
    NSArray *items = [model itemsInSection:section];
    TKMAssignment *lastAssignment = nil;
    for (int index = 0; index < items.count; ++index) {
      TKMAssignment *assignment = ((TKMSubjectModelItem *)items[index]).assignment;
      if (lastAssignment == nil || lastAssignment.srsStage != assignment.srsStage ||
          lastAssignment.isReviewStage != assignment.isReviewStage ||
          lastAssignment.isLessonStage != assignment.isLessonStage) {
        NSString *label;
        if (assignment.isReviewStage || assignment.isBurned) {
          label = TKMDetailedSRSStageName(assignment.srsStage);
        } else if (assignment.isLessonStage) {
          label = @"Available in Lessons";
        } else {
          label = @"Locked";
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

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
  [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  [vc setupWithServices:_services subject:subject];
  [self.navigationController pushViewController:vc animated:YES];
}

@end
