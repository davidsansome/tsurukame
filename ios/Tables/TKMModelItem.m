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

#import "TKMModelItem.h"

void TKMSafePerformSelector(id target, SEL selector, id object) {
  if (![target respondsToSelector:selector]) {
    return;
  }
  ((void (*)(id, SEL, id))[target methodForSelector:selector])(target, selector, object);
}

@implementation TKMModelCell : UITableViewCell

- (UIEdgeInsets)layoutMargins {
  // Override the default layout margins to match those from iOS < 13.
  return UIEdgeInsetsMake(8, 16, 8, 16);
}

- (void)updateWithItem:(id<TKMModelItem>)item {
  _item = item;
}

- (void)updateWithItem:(id<TKMModelItem>)item tableView:(UITableView *)tableView {
  _tableView = tableView;
  [self updateWithItem:item];
}

- (void)didSelectCell {
}

@end
