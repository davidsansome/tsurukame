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

#import "Extensions/ProtobufExtensions.h"
#import "SubjectDetailsViewController.h"
#import "Tables/TKMListSeparatorItem.h"
#import "Tables/TKMModelItem.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"

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
  NSMutableArray<TKMSubjectModelItem *> *radicals = [NSMutableArray array];
  NSMutableArray<TKMSubjectModelItem *> *kanji = [NSMutableArray array];

  for (TKMAssignment *assignment in [_services.localCachingClient currentLevelAssignments]) {
    if (assignment.srsStage > 4) {
      continue;
    }

    TKMSubject *subject = [_services.dataLoader loadSubject:assignment.subjectId];
    if (!subject || subject.subjectType == TKMSubject_Type_Vocabulary) {
      continue;
    }

    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                  assignment:assignment
                                                                    delegate:self];
    item.showLevelNumber = false;
    item.showAnswers = false;
    item.showRemaining = true;
    if (assignment.isLocked || assignment.isBurned) {
      item.gradientColors = TKMStyle.lockedGradient;
    }
    if (item.subject.subjectType == TKMSubject_Type_Radical) {
      [radicals addObject:item];
    } else {
      [kanji addObject:item];
    }
  }

  if ([radicals count] > 0) {
    [model addSection:@"Radicals"];
    for (TKMSubjectModelItem *item in radicals) {
      [model addItem:item];
    }
  }

  if ([kanji count] > 0) {
    [model addSection:@"Kanji"];
    for (TKMSubjectModelItem *item in kanji) {
      [model addItem:item];
    }
  }

  NSComparator comparator = ^NSComparisonResult(TKMSubjectModelItem *a, TKMSubjectModelItem *b) {
    if (a.assignment.isLocked && !b.assignment.isLocked) return NSOrderedDescending;
    if (!a.assignment.isLocked && b.assignment.isLocked) return NSOrderedAscending;
    if (a.assignment.isReviewStage && !b.assignment.isReviewStage) return NSOrderedAscending;
    if (!a.assignment.isReviewStage && b.assignment.isReviewStage) return NSOrderedDescending;
    if (a.assignment.isLessonStage && !b.assignment.isLessonStage) return NSOrderedAscending;
    if (!a.assignment.isLessonStage && b.assignment.isLessonStage) return NSOrderedDescending;
    if (a.assignment.srsStage > b.assignment.srsStage) return NSOrderedAscending;
    if (a.assignment.srsStage < b.assignment.srsStage) return NSOrderedDescending;
    return NSOrderedSame;
  };

  for (int section = 0; section < model.sectionCount; ++section) {
    [model sortSection:section usingComparator:comparator];

    NSArray *items = [model itemsInSection:section];
    TKMAssignment *lastAssignment = nil;
    for (int index = 0; index < items.count; ++index) {
      TKMAssignment *assignment = ((TKMSubjectModelItem *)items[index]).assignment;
      if (lastAssignment == nil || lastAssignment.srsStage != assignment.srsStage ||
          lastAssignment.isReviewStage != assignment.isReviewStage ||
          lastAssignment.isLessonStage != assignment.isLessonStage) {
        NSString *label;
        if (assignment.isLocked) {
          NSLog(@"%@", assignment);
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

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  [vc setupWithServices:_services subject:subject];
  [self.navigationController pushViewController:vc animated:YES];
}

@end
