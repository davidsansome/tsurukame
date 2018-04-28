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

#import "StaticHideableTableViewController.h"

@implementation StaticHideableTableViewController {
  NSMutableDictionary<NSNumber *, NSMutableIndexSet *> *_hiddenCells;
  BOOL _isInitialised;
}

#pragma mark - Initialisers

- (instancetype)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    [self initStaticHideableTableViewController];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self initStaticHideableTableViewController];
  }
  return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    [self initStaticHideableTableViewController];
  }
  return self;
}

- (void)initStaticHideableTableViewController {
  _hiddenCells = [NSMutableDictionary dictionary];
}

#pragma mark - Public methods

- (void)setIndexPath:(NSIndexPath *)index
            isHidden:(BOOL)hidden
    withRowAnimation:(UITableViewRowAnimation)animation {
  if (hidden == [self isIndexPathHidden:index]) {
    return;
  }
  
  NSNumber *section = @(index.section);
  NSMutableIndexSet *indexSet = [_hiddenCells objectForKey:section];
  // Create the index set if it didn't already exist.
  if (indexSet == nil) {
    indexSet = [NSMutableIndexSet indexSet];
    [_hiddenCells setObject:indexSet forKey:section];
  }
  
  // Update the index set.
  if (hidden) {
    [indexSet addIndex:index.row];
  } else {
    [indexSet removeIndex:index.row];
  }
  
  // Remove the index set if it's empty.
  if (indexSet.count == 0) {
    [_hiddenCells removeObjectForKey:section];
  }
  
  if (_isInitialised) {
    if (hidden) {
      [self.tableView deleteRowsAtIndexPaths:@[index] withRowAnimation:animation];
    } else {
      [self.tableView insertRowsAtIndexPaths:@[index] withRowAnimation:animation];
    }
  }
}

- (void)setIndexPath:(NSIndexPath *)index isHidden:(BOOL)hidden {
  [self setIndexPath:index isHidden:hidden withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (BOOL)isIndexPathHidden:(NSIndexPath *)index {
  return [[_hiddenCells objectForKey:@(index.section)] containsIndex:index.row];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  _isInitialised = YES;
  NSInteger rows = [super tableView:tableView numberOfRowsInSection:section];
  rows -= [[_hiddenCells objectForKey:@(section)] count];
  return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSInteger section = indexPath.section;
  __block NSInteger row = indexPath.row;
  NSIndexSet *indexSet = [_hiddenCells objectForKey:@(section)];
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    if (idx <= row) {
      row ++;
    }
  }];
  indexPath = [NSIndexPath indexPathForRow:row inSection:section];
  return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

@end
