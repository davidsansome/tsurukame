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

#import "Style.h"
#import "TKMSubjectChip.h"
#import "proto/Wanikani+Convenience.h"

static const CGFloat kChipHeight = 28.f;
static const CGFloat kLabelInset = 4.f;
static const UIEdgeInsets kLabelEdgeInsets = {kLabelInset, kLabelInset, kLabelInset, kLabelInset};
static const CGFloat kLabelHeight = kChipHeight - kLabelInset*2;
static const CGFloat kChipCornerRadius = 6.f;

static const CGFloat kChipSpacing = 8.f;

static CGFloat TextWidth(NSAttributedString *item, UIFont *font) {
  NSMutableAttributedString *str =
      [[NSMutableAttributedString alloc] initWithAttributedString:item];
  [str addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, str.length)];
  
  CGRect rect = [str boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, kLabelHeight)
                                  options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  context:nil];
  return MAX(kChipHeight, rect.size.width);
}

@implementation TKMSubjectChip {
  TKMSubject *_subject;
  __weak id<TKMSubjectDelegate> _delegate;
}

- (instancetype)initWithSubject:(TKMSubject *)subject
                           font:(UIFont *)font
                    showMeaning:(bool)showMeaning
                       delegate:(id<TKMSubjectDelegate>)delegate {
  if (showMeaning) {
    NSAttributedString *sideText = [[NSAttributedString alloc] initWithString:subject.primaryMeaning];
    return [self initWithSubject:subject
                            font:font
                        chipText:subject.japaneseText
                        sideText:sideText
                   chipTextColor:[UIColor whiteColor]
                    chipGradient:TKMGradientForSubject(subject)
                        delegate:delegate];
  } else {
    return [self initWithSubject:subject
                            font:font
                        chipText:subject.japaneseText
                        sideText:nil
                   chipTextColor:[UIColor whiteColor]
                    chipGradient:TKMGradientForSubject(subject)
                        delegate:delegate];
  }
}

- (instancetype)initWithSubject:(TKMSubject *)subject
                           font:(UIFont *)font
                       chipText:(NSAttributedString *)chipText
                       sideText:(NSAttributedString *)sideText
                  chipTextColor:(UIColor *)chipTextColor
                   chipGradient:(NSArray<id> *)chipGradient
                       delegate:(id<TKMSubjectDelegate>)delegate {
  UIFont *chipFont = [UIFont systemFontOfSize:kLabelHeight];
  CGRect chipGradientFrame = CGRectMake(0, 0, TextWidth(chipText, chipFont), kChipHeight);
  CGRect chipLabelFrame = UIEdgeInsetsInsetRect(chipGradientFrame, kLabelEdgeInsets);
  
  UILabel *chipLabel = [[UILabel alloc] initWithFrame:chipLabelFrame];
  chipLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
  chipLabel.attributedText = chipText;
  chipLabel.font = chipFont;
  chipLabel.textColor = chipTextColor;
  chipLabel.userInteractionEnabled = NO;
  chipLabel.textAlignment = NSTextAlignmentCenter;
  
  UIView *gradientView = [[UIView alloc] initWithFrame:chipGradientFrame];
  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.frame = gradientView.bounds;
  gradientLayer.cornerRadius = kChipCornerRadius;
  gradientLayer.masksToBounds = YES;
  gradientLayer.colors = chipGradient;
  [gradientView.layer insertSublayer:gradientLayer atIndex:0];
  
  CGRect totalFrame = chipGradientFrame;
  
  UILabel *sideTextLabel = nil;
  if (sideText) {
    CGRect sideTextFrame =
        CGRectMake(CGRectGetMaxX(chipGradientFrame) + kChipSpacing, 0,
                   TextWidth(sideText, font), kChipHeight);
    sideTextLabel = [[UILabel alloc] initWithFrame:sideTextFrame];
    sideTextLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    sideTextLabel.attributedText = sideText;
    sideTextLabel.font = font;
    sideTextLabel.userInteractionEnabled = NO;
    
    totalFrame = CGRectUnion(totalFrame, sideTextFrame);
  }
  
  self = [super initWithFrame:totalFrame];
  if (self) {
    _subject = subject;
    _delegate = delegate;
    
    [self addSubview:gradientView];
    [self addSubview:chipLabel];
    if (sideTextLabel) {
      [self addSubview:sideTextLabel];
    }
    
    UIGestureRecognizer *gestureRecogniser =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:gestureRecogniser];
  }
  return self;
}

- (void)handleTap:(UIGestureRecognizer *)gestureRecogniser {
  [_delegate didTapSubject:_subject];
}

@end
