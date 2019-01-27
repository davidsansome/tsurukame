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

#import "TKMCheckmarkModelItem.h"

static const CGFloat kTapAnimationWhiteness = 0.5f;
static const NSTimeInterval kTapAnimationDuration = 0.4f;

@interface TKMCheckmarkModelCell : TKMBasicModelCell
@end

@implementation TKMCheckmarkModelItem

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
  return TKMCheckmarkModelCell.class;
}

@end

@implementation TKMCheckmarkModelCell

- (void)updateWithItem:(TKMCheckmarkModelItem *)item {
  [super updateWithItem:item];
  
  self.accessoryType = item.on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void)didSelectCell {
  TKMCheckmarkModelItem *item = (TKMCheckmarkModelItem *)self.item;
  item.on = !item.on;
  TKMSafePerformSelector(item.target, item.action, item);
  self.accessoryType = item.on ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
  
  self.backgroundColor = [UIColor colorWithWhite:kTapAnimationWhiteness alpha:1.f];
  [UIView animateWithDuration:kTapAnimationDuration
                        delay:0.f
                      options:UIViewAnimationOptionCurveEaseIn
                   animations:^{
                     self.backgroundColor = [UIColor clearColor];
                   } completion:nil];
}

@end
