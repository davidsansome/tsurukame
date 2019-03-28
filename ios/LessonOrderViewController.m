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

#import "LessonOrderViewController.h"
#import "UserDefaults.h"

@interface LessonOrderViewController ()
@end

@implementation LessonOrderViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  if (![UserDefaults.lessonOrder count]) {
    UserDefaults.lessonOrder = [[NSMutableArray alloc] initWithObjects:@"Radicals",@"Kanji",@"Vocabulary",nil];
  }

  self.tableView.editing = YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return UserDefaults.lessonOrder.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cellIdentifier"];
  if(cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cellIdentifier"];  
  }
  cell.textLabel.text = [UserDefaults.lessonOrder objectAtIndex:indexPath.row];
  return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
  return NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
  NSMutableArray *copy = [[NSMutableArray alloc] initWithArray:UserDefaults.lessonOrder copyItems:YES];
  NSString *item = [copy objectAtIndex:sourceIndexPath.row];
  [copy removeObject:item];
  [copy insertObject:item atIndex:destinationIndexPath.row];
  UserDefaults.lessonOrder = copy;
}

@end
