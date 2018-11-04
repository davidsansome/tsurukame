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

#import "RandomFontsViewController.h"
#import "TKMFontLoader.h"
#import "Tables/TKMTableModel.h"
#import "Tables/TKMFontModelItem.h"
#import "UserDefaults.h"

@interface RandomFontsViewController ()

@end

@implementation RandomFontsViewController {
  TKMTableModel *_model;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSArray<TKMFont*> *fontsArray = [TKMFontLoader getLoadedFonts];
  
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView: self.tableView];
  
  [fontsArray enumerateObjectsUsingBlock:^(TKMFont *font, NSUInteger index, BOOL *stop) {
    TKMFontModelItem *item = [[TKMFontModelItem alloc] initWithFont:font];
    [model addItem:item];
    
    if (font.enabled) {
      NSIndexPath *selectedIndex = [NSIndexPath indexPathForRow:index inSection:0];
      [self.tableView selectRowAtIndexPath: selectedIndex animated:NO scrollPosition: UITableViewScrollPositionNone];
    }
  }];
  
  _model = model;
}

-(void)viewWillDisappear:(BOOL)animated {
  [TKMFontLoader saveToUserDefaults];
}

@end
