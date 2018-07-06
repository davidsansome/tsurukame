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

static const UIEdgeInsets kEdgeInsets = {8.f, 16.f, 8.f, 16.f};

@interface TKMAttributedModelCell : TKMModelCell
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
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.userInteractionEnabled = YES;
    
    _textView = [[UITextView alloc] initWithFrame:self.bounds];
    _textView.editable = NO;
    _textView.scrollEnabled = NO;
    _textView.textContainerInset = UIEdgeInsetsZero;
    _textView.textContainer.lineFragmentPadding = 0.f;
    
    [self.contentView addSubview:_textView];
  }
  return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
  CGSize availableSize = CGSizeMake(size.width - kEdgeInsets.left - kEdgeInsets.right,
                                    size.height - kEdgeInsets.top - kEdgeInsets.bottom);
  CGSize textViewSize = [_textView sizeThatFits:availableSize];
  return CGSizeMake(textViewSize.width + kEdgeInsets.left + kEdgeInsets.right,
                    textViewSize.height + kEdgeInsets.top + kEdgeInsets.bottom);
}

- (void)layoutSubviews {
  _textView.frame = UIEdgeInsetsInsetRect(self.bounds, kEdgeInsets);
}

- (void)updateWithItem:(TKMAttributedModelItem *)item {
  [super updateWithItem:item];
  
  _textView.attributedText = item.text;
}

@end
