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

#import "TKMListSeparatorItem.h"

#import "Tsurukame-Swift.h"

@implementation TKMListSeparatorItem

- (instancetype)initWithLabel:(NSString *)label {
  self = [super init];
  if (self) {
    _label = label;
  }
  return self;
}

- (NSString *)cellNibName {
  return @"TKMListSeparatorItem";
}

- (CGFloat)rowHeight {
  return 22.f;
}

@end

@implementation TKMListSeparatorCell

- (void)updateWithItem:(TKMListSeparatorItem *)item {
  _label.text = item.label;
}

- (void)didMoveToSuperview {
  [super didMoveToSuperview];
  [TKMStyle addShadowToView:_label offset:0.f opacity:1.f radius:2.f];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [[self superview] bringSubviewToFront:self];
}

@end
