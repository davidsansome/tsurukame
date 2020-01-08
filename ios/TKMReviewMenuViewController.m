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

#import "TKMReviewMenuViewController.h"

#import "Settings.h"
#import "Tables/TKMCheckmarkModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"

@interface TKMReviewMenuViewController () <UITableViewDelegate>

@property(weak, nonatomic) IBOutlet UITableView *tableView;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *rightConstraint;

@end

@implementation TKMReviewMenuViewController {
  TKMTableModel *_model;
}

- (void)rerender {
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView
                                                                       delegate:self];

  [model addSection:@"Quick settings"];
  [model
      addItem:[[TKMCheckmarkModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                     title:@"Allow cheating"
                                                  subtitle:nil
                                                        on:Settings.enableCheats
                                                    target:self
                                                    action:@selector(enableCheatsSwitchChanged:)]];
  [model addItem:[[TKMCheckmarkModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Autoreveal answers"
                          subtitle:nil
                                on:Settings.showAnswerImmediately
                            target:self
                            action:@selector(showAnswerImmediatelySwitchChanged:)]];
  [model addItem:[[TKMCheckmarkModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Autoplay audio"
                          subtitle:nil
                                on:Settings.playAudioAutomatically
                            target:self
                            action:@selector(playAudioAutomaticallySwitchChanged:)]];

  [model addSection:@"End review session"];
  TKMBasicModelItem *endReviewSession =
      [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                         title:@"End review session"
                                      subtitle:nil
                                 accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                        target:self
                                        action:@selector(endSession:)];
  endReviewSession.image = [UIImage imageNamed:@"baseline_cancel_black_24pt"];
  [model addItem:endReviewSession];

  NSString *wrapUpText;
  int wrapUpCount = [_delegate wrapUpCount];
  if (wrapUpCount) {
    wrapUpText = [NSString stringWithFormat:@"Wrap up (%d to go)", wrapUpCount];
  } else {
    wrapUpText = @"Wrap up";
  }

  TKMBasicModelItem *wrapUp =
      [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                         title:wrapUpText
                                      subtitle:nil
                                 accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                        target:self
                                        action:@selector(wrapUp:)];
  wrapUp.image = [UIImage imageNamed:@"baseline_access_time_black_24pt"];
  [model addItem:wrapUp];

  _model = model;
  [self.tableView reloadData];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self rerender];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
    willDisplayHeaderView:(UIView *)view
               forSection:(NSInteger)section {
  UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
  header.textLabel.textColor = UIColor.lightGrayColor;
}

- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
  cell.backgroundColor = self.tableView.backgroundColor;
  cell.textLabel.textColor = [UIColor whiteColor];
  cell.imageView.tintColor = [UIColor whiteColor];
  cell.tintColor = [UIColor whiteColor];
  cell.separatorInset = UIEdgeInsetsZero;
}

#pragma mark - Handlers.

- (void)enableCheatsSwitchChanged:(TKMCheckmarkModelItem *)item {
  Settings.enableCheats = item.on;
}

- (void)showAnswerImmediatelySwitchChanged:(TKMCheckmarkModelItem *)item {
  Settings.showAnswerImmediately = item.on;
}

- (void)playAudioAutomaticallySwitchChanged:(TKMCheckmarkModelItem *)item {
  Settings.playAudioAutomatically = item.on;
}

- (void)endSession:(TKMBasicModelItem *)item {
  [self.delegate didTapEndReviewSession:item.cell];
}

- (void)wrapUp:(TKMBasicModelItem *)item {
  [self.delegate didTapWrapUp];
}

@end
