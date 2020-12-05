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

#import "ReviewSummaryViewController.h"
#import "ReviewItem.h"
#import "SubjectDetailsViewController.h"
#import "Tables/TKMBasicModelItem.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"

@interface ReviewSummaryViewController () <TKMSubjectDelegate>

@end

@implementation ReviewSummaryViewController {
  TKMServices *_services;
  TKMTableModel *_model;
}

- (void)setupWithServices:(TKMServices *)services items:(NSArray<ReviewItem *> *)items {
  _services = services;
  [self setItems:items];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

- (IBAction)doneClicked:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)setItems:(NSArray<ReviewItem *> *)items {
  int currentLevel = [_services.localCachingClient getUserInfo].level;

  NSMutableDictionary<NSNumber *, NSMutableArray<ReviewItem *> *> *incorrectItemsByLevel =
      [NSMutableDictionary dictionary];
  int correct = 0;
  for (ReviewItem *item in items) {
    if (!item.answer.meaningWrong && !item.answer.readingWrong) {
      correct++;
      continue;
    }
    if (incorrectItemsByLevel[@(item.assignment.level)] == nil) {
      incorrectItemsByLevel[@(item.assignment.level)] = [NSMutableArray array];
    }
    [incorrectItemsByLevel[@(item.assignment.level)] addObject:item];
  }

  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];

  // Summary section.
  NSString *summaryText;
  if (items.count) {
    summaryText =
        [NSString stringWithFormat:@"%d%% (%d/%lu)", (int)((double)(correct) / items.count * 100),
                                   correct, (unsigned long)items.count];
  } else {
    summaryText = @"0%";
  }
  [model addSection:@"Summary"];
  [model addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                    title:@"Correct answers"
                                                 subtitle:summaryText]];

  // Add a section for each level.
  NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil
                                                                   ascending:NO
                                                                    selector:@selector(compare:)];
  NSArray<NSNumber *> *incorrectItemLevels =
      [[incorrectItemsByLevel allKeys] sortedArrayUsingDescriptors:@[ sortDescriptor ]];
  for (NSNumber *level in incorrectItemLevels) {
    if ([level intValue] == currentLevel) {
      [model addSection:[NSString stringWithFormat:@"Current level (%d)", currentLevel]];
    } else {
      [model addSection:[NSString stringWithFormat:@"Level %d", [level intValue]]];
    }

    for (ReviewItem *item in incorrectItemsByLevel[level]) {
      TKMSubject *subject = [_services.dataLoader loadSubject:item.assignment.subjectId];
      [model addItem:[[TKMSubjectModelItem alloc] initWithSubject:subject
                                                         delegate:self
                                                     readingWrong:item.answer.readingWrong
                                                     meaningWrong:item.answer.meaningWrong]];
    }
  }
  _model = model;
}

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  [vc setupWithServices:_services subject:subject];
  [self.navigationController pushViewController:vc animated:YES];
}

@end
