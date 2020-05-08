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
#import "Settings.h"
#import "proto/Wanikani+Convenience.h"

@interface TKMLessonOrderCell : UITableViewCell

@property(nonatomic) TKMSubject_Type subjectType;

@end

@implementation TKMLessonOrderCell

- (void)setSubjectType:(TKMSubject_Type)subjectType {
  _subjectType = subjectType;
  self.textLabel.text = TKMSubjectTypeName(subjectType);
}

@end

@interface LessonOrderViewController ()
@end

@implementation LessonOrderViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.tableView.editing = YES;
}

int inOrderSectionCount = 3;

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return inOrderSectionCount;
  }
  return 3 - inOrderSectionCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  TKMLessonOrderCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
  if (cell == nil) {
    cell = [[TKMLessonOrderCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:@"cell"];
  }
  cell.subjectType = [Settings.lessonOrder objectAtIndex:indexPath.row].intValue;
  return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView
    shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
  return NO;
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
           toIndexPath:(NSIndexPath *)destinationIndexPath {
  TKMLessonOrderCell *cell = [tableView cellForRowAtIndexPath:sourceIndexPath];
  if (sourceIndexPath.section == 0 && destinationIndexPath.section != 0) {
    inOrderSectionCount -= 1;
  } else if (sourceIndexPath.section != 0 && destinationIndexPath.section == 0) {
    inOrderSectionCount += 1;
  }

  NSMutableArray<NSNumber *> *lessonOrder = [Settings.lessonOrder mutableCopy];
  if (sourceIndexPath.section == 0) {
    [lessonOrder removeObjectAtIndex:sourceIndexPath.row];
  }
  if (destinationIndexPath.section == 0) {
    [lessonOrder insertObject:@(cell.subjectType) atIndex:destinationIndexPath.row];
  }
  Settings.lessonOrder = lessonOrder;
}

@end
