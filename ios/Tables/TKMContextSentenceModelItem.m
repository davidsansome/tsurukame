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
#import "TKMContextSentenceModelItem.h"

@interface TKMContextSentenceModelCell : TKMBasicModelCell
@end

@implementation TKMContextSentenceModelItem

- (instancetype)initWithJapanese:(NSString *)japanese
                         english:(NSString *)english
                            font:(UIFont *)font
                       blurrable:(bool)blurrable {
  self = [super initWithStyle:UITableViewCellStyleSubtitle
                        title:japanese
                     subtitle:english
                accessoryType:UITableViewCellAccessoryNone
                       target:nil
                       action:nil];
  if (self) {
    self.titleFont = font;
    self.subtitleFont = font;
    self.numberOfTitleLines = 0;
    self.numberOfSubtitleLines = 0;
    self.blurrable = blurrable;
  }
  return self;
}

- (Class)cellClass {
  return TKMContextSentenceModelCell.class;
}

@end

@implementation TKMContextSentenceModelCell

- (void)updateWithItem:(TKMContextSentenceModelItem *)item {
  [super updateWithItem:item];
  self.blurrable = item.blurrable;
  [self.contentView bringSubviewToFront:self.textLabel];
}

- (NSArray<UIView *> *)viewsToBlur {
  return @[self.detailTextLabel];
}

@end
