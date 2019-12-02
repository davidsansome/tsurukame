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

#import "TKMSubjectChip.h"
#import "Tsurukame-Swift.h"
#import "proto/Wanikani+Convenience.h"

@interface LessonsPageControl () <TKMSubjectChipDelegate>
@end

@implementation LessonsPageControl {
  NSMutableArray<TKMSubjectChip *> *_chips;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _chips = [NSMutableArray array];
  }
  return self;
}

#pragma mark - Layout

- (void)setSubjects:(NSArray<TKMSubject *> *)subjects {
  // Remove all existing chips.
  for (TKMSubjectChip *chip in _chips) {
    [chip removeFromSuperview];
  }
  [_chips removeAllObjects];

  // Create a chip for each subject.
  for (TKMSubject *subject in subjects) {
    TKMSubjectChip *chip = [[TKMSubjectChip alloc] initWithSubject:subject
                                                       showMeaning:false
                                                          delegate:self];
    [self addSubview:chip];
    [_chips addObject:chip];
  }

  // Create the quiz chip.
  NSAttributedString *quizText = [[NSAttributedString alloc] initWithString:@"Quiz"];
  NSArray *chipGradient = @[ (id)TKMStyle.greyColor.CGColor, (id)TKMStyle.greyColor.CGColor ];
  TKMSubjectChip *quizChip = [[TKMSubjectChip alloc] initWithSubject:nil
                                                            chipText:quizText
                                                            sideText:nil
                                                       chipTextColor:[UIColor whiteColor]
                                                        chipGradient:chipGradient
                                                            delegate:self];
  [self addSubview:quizChip];
  [_chips addObject:quizChip];

  self.currentPageIndex = _currentPageIndex;

  [self setNeedsLayout];
}

- (void)setCurrentPageIndex:(NSInteger)index {
  _currentPageIndex = index;
  for (int i = 0; i < _chips.count; ++i) {
    _chips[i].dimmed = i != index;
  }
}

- (void)layoutSubviews {
  NSArray<NSValue *> *chipFrames =
      TKMCalculateSubjectChipFrames(_chips, self.frame.size.width, NSTextAlignmentCenter);
  for (int i = 0; i < _chips.count; ++i) {
    _chips[i].frame = [chipFrames[i] CGRectValue];
  }
}

- (CGSize)sizeThatFits:(CGSize)size {
  if (!_chips.count) {
    return size;
  }
  NSArray<NSValue *> *chipFrames =
      TKMCalculateSubjectChipFrames(_chips, size.width, NSTextAlignmentCenter);
  return CGSizeMake(size.width,
                    CGRectGetMaxY([chipFrames.lastObject CGRectValue]) +
                        kTKMSubjectChipCollectionEdgeInsets.bottom);
}

#pragma mark - TKMSubjectChipDelegate

- (void)didTapSubjectChip:(TKMSubjectChip *)chip {
  for (int i = 0; i < _chips.count; ++i) {
    if (_chips[i] == chip) {
      self.currentPageIndex = i;
      [self sendActionsForControlEvents:UIControlEventValueChanged];
      break;
    }
  }
}

@end
