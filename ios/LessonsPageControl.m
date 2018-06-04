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

#import "LessonsPageControl.h"

#import "Style.h"
#import "proto/Wanikani+Convenience.h"

// Properties of the individual page icons.
static const CGFloat kPageHeight = 28.f;
static const CGFloat kLabelInset = 4.f;
static const UIEdgeInsets kLabelEdgeInsets = {kLabelInset, kLabelInset, kLabelInset, kLabelInset};
static const CGFloat kLabelHeight = kPageHeight - kLabelInset*2;
static const CGFloat kPageCornerRadius = 6.f;

// Spacing between pages.
static const CGFloat kPageSpacing = 8.f;

// Overall size of the control.
static const UIEdgeInsets kEdgeInsets = {8.f, 0.f, 4.f, 0.f};  // top, left, bottom, right

static CGFloat WidthOfItemText(NSAttributedString *item) {
  UIFont *font = [UIFont systemFontOfSize:kLabelHeight];
  NSMutableAttributedString *str =
      [[NSMutableAttributedString alloc] initWithAttributedString:item];
  [str addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, str.length)];

  CGRect rect = [str boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, kLabelHeight)
                                  options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  context:nil];
  return MAX(kPageHeight, rect.size.width);
}

@implementation LessonsPageControl {
  NSMutableArray<UILabel *> *_labels;
  NSMutableArray<UIView *> *_gradientViews;
}

#pragma mark - Layout

- (void)setSubjects:(NSArray<TKMSubject *> *)subjects {
  // Remove the old subviews, if any.
  for (UILabel *label in _labels) {
    [label removeFromSuperview];
  }
  for (UIView *view in _gradientViews) {
    [view removeFromSuperview];
  }

  _labels = [NSMutableArray array];
  _gradientViews = [NSMutableArray array];

  for (TKMSubject *subject in subjects) {
    [self appendPageItem:[subject japaneseTextWithImageSize:kLabelHeight]
               textColor:[UIColor whiteColor]
              background:TKMGradientForSubject(subject)];
  }
  [self appendPageItem:[[NSAttributedString alloc] initWithString:@"Quiz"]
             textColor:[UIColor darkGrayColor]
            background:@[(id)TKMGreyColor().CGColor, (id)TKMGreyColor().CGColor]];
  
  [self updateGradientAlpha];
  [self setNeedsLayout];
}

- (void)appendPageItem:(NSAttributedString *)text
             textColor:(UIColor *)textColor
            background:(NSArray<id> *)background {
  CGRect gradientFrame = CGRectMake(0, 0, WidthOfItemText(text), kPageHeight);
  CGRect labelFrame = UIEdgeInsetsInsetRect(gradientFrame, kLabelEdgeInsets);
  
  UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
  label.minimumScaleFactor = 0.2;
  label.adjustsFontSizeToFitWidth = YES;
  label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
  label.attributedText = text;
  label.textColor = textColor;
  label.userInteractionEnabled = NO;
  label.textAlignment = NSTextAlignmentCenter;
  
  UIGestureRecognizer *gestureRecogniser =
      [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
  
  UIView *gradientView = [[UIView alloc] initWithFrame:gradientFrame];
  [gradientView addGestureRecognizer:gestureRecogniser];
  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.frame = gradientView.bounds;
  gradientLayer.cornerRadius = kPageCornerRadius;
  gradientLayer.masksToBounds = YES;
  gradientLayer.colors = background;
  [gradientView.layer insertSublayer:gradientLayer atIndex:0];
  
  [_labels addObject:label];
  [_gradientViews addObject:gradientView];
  
  [self addSubview:gradientView];
  [self addSubview:label];
}

- (void)setCurrentPageIndex:(NSInteger)index {
  _currentPageIndex = index;
  [self updateGradientAlpha];
}

- (CGSize)intrinsicContentSizeWithoutPadding {
  CGFloat width = kPageSpacing * (_gradientViews.count - 1);
  for (UIView *view in _gradientViews) {
    width += view.frame.size.width;
  }
  return CGSizeMake(width, kPageHeight);
}

- (CGSize)intrinsicContentSize {
  CGSize size = self.intrinsicContentSizeWithoutPadding;
  size.width += kEdgeInsets.left + kEdgeInsets.right;
  size.height += kEdgeInsets.bottom + kEdgeInsets.top;
  return size;
}

- (void)layoutSubviews {
  [super layoutSubviews];

  CGSize contentSize = self.intrinsicContentSizeWithoutPadding;
  CGPoint pageOrigin = CGPointMake((self.bounds.size.width - contentSize.width) / 2,
                                   (self.bounds.size.height - contentSize.height) / 2);
  
  for (NSInteger i = 0; i < _gradientViews.count; ++i) {
    UIView *gradientView = _gradientViews[i];
    UILabel *label = _labels[i];
    
    CGRect gradientFrame = {pageOrigin, gradientView.bounds.size};
    CGRect labelFrame = UIEdgeInsetsInsetRect(gradientFrame, kLabelEdgeInsets);
    
    gradientView.frame = gradientFrame;
    label.frame = labelFrame;

    pageOrigin.x += gradientFrame.size.width + kPageSpacing;
  }
}

- (void)updateGradientAlpha {
  for (NSInteger i = 0; i < _gradientViews.count; ++i) {
    CGFloat alpha = (i == _currentPageIndex) ? 1.0 : 0.5;
    _gradientViews[i].alpha = alpha;
  }
}

- (void)handleTap:(UIGestureRecognizer *)gestureRecogniser {
  for (NSInteger i = 0; i < _gradientViews.count; ++i) {
    if (_gradientViews[i] == gestureRecogniser.view) {
      _currentPageIndex = i;
      [self updateGradientAlpha];
      [self sendActionsForControlEvents:UIControlEventValueChanged];
      break;
    }
  }
}

@end
