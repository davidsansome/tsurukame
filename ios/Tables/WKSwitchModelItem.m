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

#import "WKSwitchModelItem.h"

@interface WKSwitchModelCell : WKBasicModelCell
@end

@implementation WKSwitchModelItem

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                           on:(BOOL)on
                       target:(id)target
                       action:(SEL)action {
  self = [super initWithStyle:style
                        title:title
                     subtitle:subtitle
                accessoryType:UITableViewCellAccessoryNone
                       target:target
                       action:action];
  if (self) {
    _on = on;
  }
  return self;
}

- (Class)cellClass {
  return WKSwitchModelCell.class;
}

@end

@implementation WKSwitchModelCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
  }
  return self;
}

- (UISwitch *)switchView {
  return (UISwitch *)self.accessoryView;
}

- (void)updateWithItem:(WKSwitchModelItem *)item {
  [self.switchView removeTarget:nil action:nil forControlEvents:UIControlEventValueChanged];
  
  [super updateWithItem:item];
  
  self.switchView.on = item.on;
  [self.switchView addTarget:item.target action:item.action forControlEvents:UIControlEventValueChanged];
}

- (void)didSelectCell {
  [self.switchView setOn:!self.switchView.on animated:YES];
  [self.switchView sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
