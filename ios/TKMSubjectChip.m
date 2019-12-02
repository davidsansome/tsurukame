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

#import "TKMSubjectChip.h"
#import "Tsurukame-Swift.h"
#import "proto/Wanikani+Convenience.h"

static const CGFloat kChipHeight = 28.f;
static const CGFloat kLabelInset = 6.f;
static const CGFloat kLabelHeight = kChipHeight - kLabelInset * 2;
static const CGFloat kChipCornerRadius = 6.f;

static const CGFloat kChipHorizontalSpacing = 8.f;

const UIEdgeInsets kTKMSubjectChipCollectionEdgeInsets = {8.f, 16.f, 8.f, 16.f};
static const CGFloat kChipVerticalSpacing = 3.f;

static CGFloat TextWidth(NSAttributedString *item, UIFont *font) {
  NSMutableAttributedString *str =
      [[NSMutableAttributedString alloc] initWithAttributedString:item];
  [str addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, str.length)];

  CGRect rect = [str
      boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, kLabelHeight)
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                   context:nil];
  return MAX(kLabelHeight, rect.size.width);
}

static void AlignChipFrames(NSMutableArray<NSValue *> *chipFrames, CGFloat width,
                            NSUInteger *unalignedFrameIndex, NSTextAlignment alignment) {
  if (alignment != NSTextAlignmentCenter) {
    return;
  }
  CGFloat totalWidth = width - kTKMSubjectChipCollectionEdgeInsets.left * 2;
  CGFloat chipTotalWidth =
      CGRectGetMaxX([chipFrames.lastObject CGRectValue]) - kTKMSubjectChipCollectionEdgeInsets.left;
  CGFloat offset = (totalWidth - chipTotalWidth) / 2;

  for (NSUInteger i = *unalignedFrameIndex; i < chipFrames.count; ++i) {
    CGRect rect = [chipFrames[i] CGRectValue];
    rect.origin.x += offset;
    [chipFrames replaceObjectAtIndex:i withObject:[NSValue valueWithCGRect:rect]];
  }
  *unalignedFrameIndex = chipFrames.count;
}

NSArray<NSValue *> *TKMCalculateSubjectChipFrames(NSArray<TKMSubjectChip *> *chips, CGFloat width,
                                                  NSTextAlignment alignment) {
  NSMutableArray<NSValue *> *chipFrames = [NSMutableArray array];
  NSUInteger unalignedFrameIndex = 0;

  CGPoint origin = CGPointMake(kTKMSubjectChipCollectionEdgeInsets.left,
                               kTKMSubjectChipCollectionEdgeInsets.top);
  for (TKMSubjectChip *chip in chips) {
    CGRect chipFrame = chip.frame;
    chipFrame.origin = origin;

    if (CGRectGetMaxX(chipFrame) > width - kTKMSubjectChipCollectionEdgeInsets.right) {
      AlignChipFrames(chipFrames, width, &unalignedFrameIndex, alignment);
      chipFrame.origin.y += chipFrame.size.height + kChipVerticalSpacing;
      chipFrame.origin.x = kTKMSubjectChipCollectionEdgeInsets.left;
    }

    [chipFrames addObject:[NSValue valueWithCGRect:chipFrame]];
    origin = CGPointMake(CGRectGetMaxX(chipFrame) + kChipHorizontalSpacing, chipFrame.origin.y);
  }
  AlignChipFrames(chipFrames, width, &unalignedFrameIndex, alignment);
  return chipFrames;
}

@implementation TKMSubjectChip {
  __weak id<TKMSubjectChipDelegate> _delegate;

  __weak UIView *_gradientView;
}

- (instancetype)initWithSubject:(TKMSubject *)subject
                    showMeaning:(bool)showMeaning
                       delegate:(id<TKMSubjectChipDelegate>)delegate {
  NSAttributedString *japaneseText = [subject japaneseTextWithImageSize:kLabelHeight];
  if (showMeaning) {
    NSAttributedString *sideText =
        [[NSAttributedString alloc] initWithString:subject.primaryMeaning];
    return [self initWithSubject:subject
                        chipText:japaneseText
                        sideText:sideText
                   chipTextColor:[UIColor whiteColor]
                    chipGradient:[TKMStyle gradientForSubject:subject]
                        delegate:delegate];
  } else {
    return [self initWithSubject:subject
                        chipText:japaneseText
                        sideText:nil
                   chipTextColor:[UIColor whiteColor]
                    chipGradient:[TKMStyle gradientForSubject:subject]
                        delegate:delegate];
  }
}

- (instancetype)initWithSubject:(nullable TKMSubject *)subject
                       chipText:(NSAttributedString *)chipText
                       sideText:(nullable NSAttributedString *)sideText
                  chipTextColor:(UIColor *)chipTextColor
                   chipGradient:(NSArray<id> *)chipGradient
                       delegate:(id<TKMSubjectChipDelegate>)delegate {
  UIFont *chipFont = [TKMStyle japaneseFontWithSize:kLabelHeight];
  CGRect chipLabelFrame =
      CGRectMake(kLabelInset, kLabelInset, TextWidth(chipText, chipFont), kLabelHeight);
  CGRect chipGradientFrame = CGRectMake(0, 0, CGRectGetMaxX(chipLabelFrame) + kLabelInset,
                                        CGRectGetMaxY(chipLabelFrame) + kLabelInset);

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
  _gradientView = gradientView;

  CGRect totalFrame = chipGradientFrame;

  UILabel *sideTextLabel = nil;
  if (sideText) {
    UIFont *sideTextFont = [UIFont systemFontOfSize:14.f];
    CGRect sideTextFrame =
        CGRectMake(CGRectGetMaxX(chipGradientFrame) + kChipHorizontalSpacing, 0,
                   TextWidth(sideText, sideTextFont) + kChipHorizontalSpacing, kChipHeight);
    sideTextLabel = [[UILabel alloc] initWithFrame:sideTextFrame];
    sideTextLabel.font = sideTextFont;
    sideTextLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    sideTextLabel.attributedText = sideText;
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
  [_delegate didTapSubjectChip:self];
}

- (void)setDimmed:(bool)dimmed {
  _gradientView.alpha = dimmed ? 0.5f : 1.f;
}

- (bool)isDimmed {
  return _gradientView.alpha < 0.75f;
}

@end
