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

#import "TKMFontModelItem.h"

@interface TKMFontModelView ()

@property (weak, nonatomic) IBOutlet UILabel *fontNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *fontPreviewLabel;

@end

@implementation TKMFontModelView

- (void)updateWithItem:(TKMFontModelItem *)item {
  [super updateWithItem:item];
  
  _fontNameLabel.text = item.font.fontName;
  NSUInteger oldSize = _fontPreviewLabel.font.pointSize;
  _fontPreviewLabel.font = [UIFont fontWithName:item.font.fontName size:oldSize];
  _fontPreviewLabel.text = @"あいうえお\n漢字 字体";
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
  if (!selected && [TKMFontLoader getEnabledFonts].count == 1) {
    return;
  }
  [(TKMFontModelItem*)self.item setSelected:selected];
  self.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end

@implementation TKMFontModelItem

- (instancetype)initWithFont:(TKMFont *)font {
  self = [super init];
  if (self) {
    _font = font;
  }
  return self;
}

- (void)setSelected:(BOOL)selected {
  _font.enabled = selected;
}

- (NSString *)cellNibName {
  return @"TKMFontModelItem";
}

@end
