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

#import <UIKit/UIKit.h>

#import "TKMModelItem.h"

@interface TKMTableModel : NSObject <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, readonly, weak) UITableView *tableView;
@property(nonatomic, readonly) int sectionCount;

- (instancetype)initWithTableView:(UITableView *)tableView NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)setIndexPath:(NSIndexPath *)index isHidden:(BOOL)hidden;
- (BOOL)isIndexPathHidden:(NSIndexPath *)index;

- (NSArray<id<TKMModelItem>> *)itemsInSection:(int)section;

@end

@interface TKMMutableTableModel : TKMTableModel

- (int)addSection;
- (int)addSection:(NSString *)title;
- (int)addSection:(NSString *)title footer:(NSString *)footer;
- (NSIndexPath *)addItem:(id<TKMModelItem>)item;
- (NSIndexPath *)addItem:(id<TKMModelItem>)item toSection:(int)section;
- (NSIndexPath *)addItem:(id<TKMModelItem>)item hidden:(bool)hidden;
- (NSIndexPath *)addItem:(id<TKMModelItem>)item toSection:(int)section hidden:(bool)hidden;
- (NSIndexPath *)insertItem:(id<TKMModelItem>)item atIndex:(int)index inSection:(int)section;

- (void)sortSection:(int)section usingComparator:(NSComparator)comparator;

- (void)reloadTable;

@end
