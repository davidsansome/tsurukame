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

#import "TKMLeechesViewController.h"

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

static NSString *LeechScoreText(int score) {
  if (score > 1500) {
    return @"Fiendish";
  }
  if (score > 1000) {
    return @"Extreme";
  }
  if (score > 750) {
    return @"Very difficult";
  }
  if (score > 600) {
    return @"Difficult";
  }
  if (score > 500) {
    return @"Challenging";
  }
  return @"Needs Improvement";
}

@interface TKMLeechesViewController () <TKMSubjectDelegate>
@end

@implementation TKMLeechesViewController {
  TKMServices *_services;
  TKMTableModel *_model;
  UISwitch *_answerSwitch;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.title = @"Leeches";
  
  _answerSwitch = [[UISwitch alloc] init];
  _answerSwitch.on = YES;
  [_answerSwitch addTarget:self
                    action:@selector(answerSwitchChanged:)
          forControlEvents:UIControlEventValueChanged];
  self.navigationItem.rightBarButtonItem =
  [[UIBarButtonItem alloc] initWithCustomView:_answerSwitch];
  
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];
  
  NSString *lastSectionText;
  
  for (TKMReviewStats *stats in [_services.localCachingClient getLeeches]) {
    TKMSubject *subject = [_services.dataLoader loadSubject:stats.subjectId];
    if (!subject) {
      continue;
    }
    
    TKMAssignment *assignment = [_services.localCachingClient getAssignmentForID:stats.subjectId];
    
    int score = stats.hasReading ? stats.reading.score : stats.meaning.score;
    NSString *sectionText = LeechScoreText(score);
    if (!lastSectionText || ![lastSectionText isEqual:sectionText]) {
      [model addItem:[[TKMListSeparatorItem alloc] initWithLabel:sectionText]];
      lastSectionText = sectionText;
    }
    
    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                    delegate:self];
    item.assignment = assignment;
    item.reviewStats = stats;
    item.showOnlyWrongPart = true;
    item.showOnlyFirstMeaning = true;
    item.showSRSStage = true;
    item.meaningWrong = stats.hasMeaning;
    item.readingWrong = stats.hasReading;
    [model addItem:item];
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
      [subjectCell setShowAnswers:showAnswers animated:YES];
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
