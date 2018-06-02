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

#import "WKBasicModelItem.h"

@implementation WKBasicModelItem

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType
                       target:(id)target
                       action:(SEL)action {
  self = [super init];
  if (self) {
    _style = style;
    _title = title;
    _subtitle = subtitle;
    _accessoryType = accessoryType;
    _target = target;
    _action = action;
  }
  return self;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType {
  return [self initWithStyle:style
                       title:title
                    subtitle:subtitle
               accessoryType:accessoryType
                      target:nil
                      action:nil];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle {
  return [self initWithStyle:style
                       title:title
                    subtitle:subtitle
               accessoryType:UITableViewCellAccessoryNone];
}

- (Class)cellClass {
  return WKBasicModelCell.class;
}

- (NSString *)cellReuseIdentifier {
  return [NSString stringWithFormat:@"%s/%ld",
          object_getClassName(self.cellClass),
          (long)_style];
}

- (WKModelCell *)createCell {
  return [[self.cellClass alloc] initWithStyle:_style reuseIdentifier:self.cellReuseIdentifier];
}

@end

@implementation WKBasicModelCell

- (void)updateWithItem:(WKBasicModelItem *)item {
  [super updateWithItem:item];
  
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  
  self.textLabel.text = item.title;
  self.detailTextLabel.text = item.subtitle;
  self.accessoryType = item.accessoryType;
  self.textLabel.textColor = item.textColor;
}

- (void)didSelectCell {
  WKBasicModelItem *item = (WKBasicModelItem *)self.item;
  WKSafePerformSelector(item.target, item.action, item);
}

@end
