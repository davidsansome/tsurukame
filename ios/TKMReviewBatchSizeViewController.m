// Copyright 2020 David Sansome
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

#import "TKMReviewBatchSizeViewController.h"
#import "Settings.h"

@interface TKMReviewBatchSizeViewController ()

@end

@implementation TKMReviewBatchSizeViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  NSInteger selectedRow = Settings.reviewBatchSize - 3;
  if (selectedRow < 0 || selectedRow >= [self.tableView numberOfRowsInSection:0]) {
    selectedRow = 0;
  }
  NSIndexPath *selectedIndex = [NSIndexPath indexPathForRow:selectedRow inSection:0];
  UITableViewCell *selectedCell = [self tableView:self.tableView
                            cellForRowAtIndexPath:selectedIndex];
  selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  Settings.reviewBatchSize = (int)indexPath.row + 3;
  [self.navigationController popViewControllerAnimated:YES];
}

@end
