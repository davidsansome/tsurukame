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

#import "TKMAttributedModelItem.h"
#import "TKMBlurrableCell.h"

static const CGFloat kMinimumHeight = 44.f;

@interface TKMAttributedModelCell : TKMBlurrableCell
@end

@implementation TKMAttributedModelItem

- (instancetype)initWithText:(NSAttributedString *)text {
  self = [super init];
  if (self) {
    _text = text;
  }
  return self;
}

- (Class)cellClass {
  return TKMAttributedModelCell.class;
}

@end

@implementation TKMAttributedModelCell {
  UITextView *_textView;
  NSLayoutConstraint *_topConstraint;
  NSLayoutConstraint *_bottomConstraint;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.userInteractionEnabled = YES;
    
    _textView = [[UITextView alloc] initWithFrame:self.contentView.bounds];
    _textView.editable = NO;
    _textView.scrollEnabled = NO;
    _textView.textContainerInset = UIEdgeInsetsZero;
    _textView.textContainer.lineFragmentPadding = 0.f;
    _textView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addSubview:_textView];
    
    UILayoutGuide *guide = self.contentView.layoutMarginsGuide;
    _topConstraint = [_textView.topAnchor constraintEqualToAnchor:guide.topAnchor];
    _bottomConstraint = [_textView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor];
    _topConstraint.active = YES;
    _bottomConstraint.active = YES;
    [_textView.leftAnchor constraintEqualToAnchor:guide.leftAnchor].active = YES;
    [_textView.rightAnchor constraintEqualToAnchor:guide.rightAnchor].active = YES;
  }
  return self;
}

- (void)updateWithItem:(TKMAttributedModelItem *)item {
  [super updateWithItem:item];
  
  self.blurrable = item.blurrable;
  _textView.attributedText = item.text;
}

- (void)updateConstraints {
  CGRect availableRect = UIEdgeInsetsInsetRect(self.contentView.bounds, self.contentView.layoutMargins);
  CGSize textSize = [_textView sizeThatFits:availableRect.size];
  CGFloat height = self.contentView.layoutMargins.top + textSize.height + self.contentView.layoutMargins.bottom;
  
  CGFloat missingHeight = kMinimumHeight - height;
  if (missingHeight > 0.f) {
    CGFloat extraTopSpace = floor(missingHeight / 2.f);
    CGFloat extraBottomSpace = missingHeight - extraTopSpace;
    _topConstraint.constant = extraTopSpace;
    _bottomConstraint.constant = -extraBottomSpace;
  }
  
  [super updateConstraints];
}

@end
