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

- (void)setupWithServices:(TKMServices *)services
                    items:(NSArray<ReviewItem *> *)items
                leveledUp:(BOOL)leveledUp
                fromLevel:(int)level {
  _services = services;
  [self setItems:items leveledUp:leveledUp fromLevel:level];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

- (IBAction)doneClicked:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)showAnswerClicked:(id)sender {
  UISwitch *switchObject = (UISwitch *)sender;
  Settings.reviewSummaryViewShowAnswers = switchObject.on;
  [self setShowAnswers:Settings.reviewSummaryViewShowAnswers animated:true];
}

- (void)setItems:(NSArray<ReviewItem *> *)items leveledUp:(BOOL)leveledUp fromLevel:(int)fromLevel {
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
  // Level-up summary
  int currentLevel = fromLevel;
  if (Settings.animateWKLevelUpPopup && leveledUp) {
    [model addSection:@"Level-Up Summary"];
    TKMBasicModelItem *modelItem;
    if (fromLevel != 60) {
      currentLevel++;
      modelItem = [[TKMBasicModelItem alloc]
          initWithStyle:UITableViewCellStyleSubtitle
                  title:[NSString stringWithFormat:@"Level-up to %d", currentLevel]
               subtitle:@"The Crabigator has new lessons for you!"];
      if (currentLevel == 42)
        modelItem.subtitle = @"Koichi is proud of you! You have a few lessons!";
    } else {
      modelItem = [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                     title:@"Level-up to 61!"
                                                  subtitle:
                                                      @"There's no level 61 yet. The Crabiagtor "
                                                      @"congratulates you! No new lessons yet!"];
    }
    modelItem.image = [UIImage imageNamed:@"cherryblossom"];
    [model addItem:modelItem];
  }

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
      TKMSubjectModelItem *modelItem =
          [[TKMSubjectModelItem alloc] initWithSubject:subject
                                              services:_services
                                              delegate:self
                                          readingWrong:item.answer.readingWrong
                                          meaningWrong:item.answer.meaningWrong];
      modelItem.showAnswers = Settings.reviewSummaryViewShowAnswers;
      [model addItem:modelItem];
    }
  }
  _model = model;
}

- (void)setShowAnswers:(bool)showAnswers animated:(bool)animated {
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
