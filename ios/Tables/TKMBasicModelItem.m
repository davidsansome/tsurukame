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

#import "TKMBasicModelItem.h"

@implementation TKMBasicModelItem

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType
                       target:(nullable id)target
                       action:(nullable SEL)action {
  self = [super init];
  if (self) {
    _style = style;
    _title = title;
    _numberOfTitleLines = 1;
    _subtitle = subtitle;
    _numberOfSubtitleLines = 1;
    _accessoryType = accessoryType;
    _target = target;
    _action = action;

    if (style == UITableViewCellStyleSubtitle) {
      _subtitleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    }
  }
  return self;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType {
  return [self initWithStyle:style
                       title:title
                    subtitle:subtitle
               accessoryType:accessoryType
                      target:nil
                      action:nil];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle {
  return [self initWithStyle:style
                       title:title
                    subtitle:subtitle
               accessoryType:UITableViewCellAccessoryNone];
}

- (Class)cellClass {
  return TKMBasicModelCell.class;
}

- (NSString *)cellReuseIdentifier {
  return [NSString stringWithFormat:@"%s/%ld", object_getClassName(self.cellClass), (long)_style];
}

- (TKMModelCell *)createCell {
  return [[self.cellClass alloc] initWithStyle:_style reuseIdentifier:self.cellReuseIdentifier];
}

@end

@implementation TKMBasicModelCell

- (void)updateWithItem:(TKMBasicModelItem *)item {
  [super updateWithItem:item];

  self.selectionStyle = UITableViewCellSelectionStyleNone;

  self.textLabel.text = item.title;
  self.textLabel.font = item.titleFont;
  self.textLabel.textColor = item.titleTextColor;
  self.textLabel.numberOfLines = item.numberOfTitleLines;
  self.detailTextLabel.text = item.subtitle;
  self.detailTextLabel.font = item.subtitleFont;
  self.detailTextLabel.textColor = item.subtitleTextColor;
  self.detailTextLabel.numberOfLines = item.numberOfSubtitleLines;
  self.accessoryType = item.accessoryType;
  self.textLabel.textColor = item.textColor;
  self.imageView.image = item.image;

  item.cell = self;
}

- (void)didSelectCell {
  TKMBasicModelItem *item = (TKMBasicModelItem *)self.item;
  TKMSafePerformSelector(item.target, item.action, item);
}

@end
