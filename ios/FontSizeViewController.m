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

#import "FontSizeViewController.h"
#import "Settings.h"

@interface FontSizeViewController ()
@end

@implementation FontSizeViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  NSInteger selectedRow = 0;
  switch ((int)(Settings.fontSize * 100)) {
    case 125:
      selectedRow = 1;
      break;

    case 150:
      selectedRow = 2;
      break;

    case 175:
      selectedRow = 3;
      break;

    case 200:
      selectedRow = 4;
      break;

    case 225:
      selectedRow = 5;
      break;

    case 250:
      selectedRow = 6;
      break;

    default:
      selectedRow = 0;
      break;
  }

  if (selectedRow < 0 || selectedRow >= [self.tableView numberOfRowsInSection:0]) {
    selectedRow = 0;
  }
  NSIndexPath *selectedIndex = [NSIndexPath indexPathForRow:selectedRow inSection:0];
  UITableViewCell *selectedCell = [self tableView:self.tableView
                            cellForRowAtIndexPath:selectedIndex];
  selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  switch ((int)indexPath.row) {
    case 1:
      Settings.fontSize = 1.25;
      break;

    case 2:
      Settings.fontSize = 1.5;
      break;

    case 3:
      Settings.fontSize = 1.75;
      break;

    case 4:
      Settings.fontSize = 2.0;
      break;

    case 5:
      Settings.fontSize = 2.25;
      break;

    case 6:
      Settings.fontSize = 2.5;
      break;

    default:
      Settings.fontSize = 1.0;
      break;
  }

  [self.navigationController popViewControllerAnimated:YES];
}

@end
