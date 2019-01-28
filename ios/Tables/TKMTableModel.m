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

#import "TKMTableModel.h"

@interface TKMTableModelSection : NSObject

@property(nonatomic) NSString *headerTitle;
@property(nonatomic) NSString *footerTitle;
@property(nonatomic) NSMutableArray<id<TKMModelItem>> *items;
@property(nonatomic) NSMutableIndexSet *hiddenItems;

@end

@implementation TKMTableModelSection

- (instancetype)init {
  self = [super init];
  if (self) {
    _items = [NSMutableArray array];
    _hiddenItems = [NSMutableIndexSet indexSet];
  }
  return self;
}

@end

@interface TKMTableModel ()

@property(nonatomic) NSMutableArray<TKMTableModelSection *> *sections;

@end

@implementation TKMTableModel {
  BOOL _isInitialised;
}

- (void)dealloc {
  if (!_isInitialised) {
    NSLog(@"TKMTableModel deallocated without being used. Did you forget to retain it?");
  }
}

- (instancetype)initWithTableView:(UITableView *)tableView
                         delegate:(nullable id<UITableViewDelegate>)delegate {
  self = [super init];
  if (self) {
    _tableView = tableView;
    _sections = [NSMutableArray array];
    _delegate = delegate;

    _tableView.dataSource = self;
    _tableView.delegate = self;
  }
  return self;
}

- (instancetype)initWithTableView:(UITableView *)tableView {
  return [self initWithTableView:tableView delegate:nil];
}

- (int)sectionCount {
  return (int)self.sections.count;
}

- (NSArray<id<TKMModelItem>> *)itemsInSection:(int)section {
  return self.sections[section].items;
}

#pragma mark - Hiding items

- (void)setIndexPath:(NSIndexPath *)index isHidden:(BOOL)hidden {
  if (hidden == [self isIndexPathHidden:index]) {
    return;
  }

  NSMutableIndexSet *indexSet = _sections[index.section].hiddenItems;
  if (hidden) {
    [indexSet addIndex:index.row];
  } else {
    [indexSet removeIndex:index.row];
  }

  if (_isInitialised) {
    if (hidden) {
      [_tableView deleteRowsAtIndexPaths:@[ index ]
                        withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
      [_tableView insertRowsAtIndexPaths:@[ index ]
                        withRowAnimation:UITableViewRowAnimationAutomatic];
    }
  }
}

- (BOOL)isIndexPathHidden:(NSIndexPath *)index {
  return [_sections[index.section].hiddenItems containsIndex:index.row];
}

#pragma mark - UITableViewDataSource

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
  TKMTableModelSection *section = _sections[indexPath.section];
  __block NSInteger row = indexPath.row;
  [section.hiddenItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *_Nonnull stop) {
    if (idx <= row) {
      row++;
    }
  }];

  return [self cellForItem:section.items[row]];
}

- (nonnull UITableViewCell *)cellForItem:(id<TKMModelItem>)item {
  NSString *reuseIdentifier;
  if ([item respondsToSelector:@selector(cellReuseIdentifier)]) {
    reuseIdentifier = [item cellReuseIdentifier];
  } else {
    reuseIdentifier = @(object_getClassName(item.class));
  }

  TKMModelCell *cell = [_tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
  if (!cell) {
    if ([item respondsToSelector:@selector(createCell)]) {
      cell = [item createCell];
    } else if ([item respondsToSelector:@selector(cellNibName)]) {
      cell = [_tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
      if (!cell) {
        UINib *nib = [UINib nibWithNibName:item.cellNibName bundle:nil];
        [_tableView registerNib:nib forCellReuseIdentifier:reuseIdentifier];
        cell = [_tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
      }
    } else if ([item respondsToSelector:@selector(cellClass)]) {
      Class cellClass = [item cellClass];
      cell = [[cellClass alloc] initWithStyle:UITableViewCellStyleDefault
                              reuseIdentifier:reuseIdentifier];
    } else {
      NSAssert(false,
               @"Item class %@ should respond to either createCell, cellNibName or cellClass",
               reuseIdentifier);
    }
  }

  // Disable animations when reusing a cell.
  [CATransaction begin];
  [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
  [cell updateWithItem:item];
  [CATransaction commit];
  return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  return _sections[section].headerTitle;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  return _sections[section].footerTitle;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  _isInitialised = YES;
  return _sections.count;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  TKMTableModelSection *s = _sections[section];
  return s.items.count - s.hiddenItems.count;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  TKMModelCell *cell = [tableView cellForRowAtIndexPath:indexPath];
  [cell didSelectCell];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  id<TKMModelItem> item = _sections[indexPath.section].items[indexPath.item];
  if ([item respondsToSelector:@selector(rowHeight)]) {
    return [item rowHeight];
  }
  return tableView.rowHeight;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if ([self.delegate respondsToSelector:aSelector]) {
    return YES;
  }
  return [super respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
  if ([self.delegate respondsToSelector:aSelector]) {
    return self.delegate;
  }
  return [super forwardingTargetForSelector:aSelector];
}

@end

@implementation TKMMutableTableModel

- (int)addSection {
  return [self addSection:nil footer:nil];
}

- (int)addSection:(nullable NSString *)title {
  return [self addSection:title footer:nil];
}

- (int)addSection:(nullable NSString *)title footer:(nullable NSString *)footer {
  TKMTableModelSection *section = [[TKMTableModelSection alloc] init];
  section.headerTitle = title;
  section.footerTitle = footer;

  int index = (int)self.sections.count;
  [self.sections addObject:section];
  return index;
}

- (NSIndexPath *)addItem:(id<TKMModelItem>)item toSection:(int)sectionIndex hidden:(bool)hidden {
  TKMTableModelSection *section = self.sections[sectionIndex];
  [section.items addObject:item];

  NSIndexPath *indexPath = [NSIndexPath indexPathForRow:section.items.count - 1
                                              inSection:sectionIndex];
  if (hidden) {
    [self setIndexPath:indexPath isHidden:YES];
  }
  return indexPath;
}

- (NSIndexPath *)addItem:(id<TKMModelItem>)item {
  return [self addItem:item hidden:NO];
}

- (NSIndexPath *)addItem:(id<TKMModelItem>)item hidden:(bool)hidden {
  if (self.sections.count == 0) {
    [self addSection];
  }
  return [self addItem:item toSection:(int)self.sections.count - 1 hidden:hidden];
}

- (NSIndexPath *)addItem:(id<TKMModelItem>)item toSection:(int)section {
  return [self addItem:item toSection:section hidden:NO];
}

- (NSIndexPath *)insertItem:(id<TKMModelItem>)item atIndex:(int)index inSection:(int)section {
  [self.sections[section].items insertObject:item atIndex:index];
  return [NSIndexPath indexPathForRow:index inSection:section];
}

- (void)sortSection:(int)section usingComparator:(NSComparator)comparator {
  [self.sections[section].items sortUsingComparator:comparator];
}

- (void)reloadTable {
  [self.tableView reloadData];
}

@end
