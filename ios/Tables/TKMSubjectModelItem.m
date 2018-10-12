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

#import "DataLoader.h"
#import "TKMSubjectChip.h"
#import "TKMSubjectModelItem.h"
#import "Style.h"
#import "proto/Wanikani+Convenience.h"

static const CGFloat kJapaneseTextImageSize = 26.f;

static UIFont *kNormalFont;
static UIFont *kCorrectFont;
static UIFont *kIncorrectFont;

@interface TKMSubjectModelView ()
@property (weak, nonatomic) IBOutlet UILabel *levelLabel;
@property (weak, nonatomic) IBOutlet UILabel *subjectLabel;
@property (weak, nonatomic) IBOutlet UILabel *readingLabel;
@property (weak, nonatomic) IBOutlet UILabel *meaningLabel;
@property (weak, nonatomic) IBOutlet UIStackView *answerStack;
@end

@implementation TKMSubjectModelItem

- (instancetype)initWithSubject:(TKMSubject *)subject
                       delegate:(id<TKMSubjectDelegate>)delegate
                   readingWrong:(bool)readingWrong
                   meaningWrong:(bool)meaningWrong {
  self = [super init];
  if (self) {
    _subject = subject;
    _delegate = delegate;
    _meaningWrong = meaningWrong;
    _readingWrong = readingWrong;
    _showLevelNumber = true;
    _showAnswers = true;
  }
  return self;
}

- (instancetype)initWithSubject:(TKMSubject *)subject
                     assignment:(TKMAssignment *)assignment
                       delegate:(id<TKMSubjectDelegate>)delegate {
  self = [self initWithSubject:subject delegate:delegate readingWrong:false meaningWrong:false];
  if (self) {
    self.assignment = assignment;
  }
  return self;
}

- (instancetype)initWithSubject:(TKMSubject *)subject
                       delegate:(id<TKMSubjectDelegate>)delegate {
  return [self initWithSubject:subject delegate:delegate readingWrong:false meaningWrong:false];
}

- (NSString *)cellNibName {
  return @"TKMSubjectModelItem";
}

@end

@implementation TKMSubjectModelView {
  __weak CAGradientLayer *_gradient;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kNormalFont = [UIFont systemFontOfSize:14.0f];
    kCorrectFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightThin];
    kIncorrectFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightBold];
  });
  
  self = [super initWithCoder:aDecoder];
  if (self) {
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    _gradient = gradientLayer;
    [self.contentView.layer insertSublayer:gradientLayer atIndex:0];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _gradient.frame = self.contentView.bounds;
}

#pragma mark - TKMModelCell

- (void)updateWithItem:(TKMSubjectModelItem *)item {
  [super updateWithItem:item];
  
  self.levelLabel.hidden = !item.showLevelNumber;
  if (item.showLevelNumber) {
    self.levelLabel.text = [NSString stringWithFormat:@"%d", item.subject.level];
  }
  _gradient.colors = item.gradientColors ?: TKMGradientForSubject(item.subject);
  
  self.subjectLabel.attributedText = [item.subject japaneseTextWithImageSize:kJapaneseTextImageSize];
  if (item.subject.hasRadical) {
    [self.readingLabel setHidden:YES];
    self.meaningLabel.text = item.subject.commaSeparatedMeanings;
  } else if (item.subject.hasKanji) {
    [self.readingLabel setHidden:NO];
    self.readingLabel.text = item.subject.commaSeparatedPrimaryReadings;
    self.meaningLabel.text = item.subject.commaSeparatedMeanings;
  } else if (item.subject.hasVocabulary) {
    [self.readingLabel setHidden:NO];
    self.readingLabel.text = item.subject.commaSeparatedReadings;
    self.meaningLabel.text = item.subject.commaSeparatedMeanings;
  }
  
  if (!item.readingWrong && !item.meaningWrong) {
    self.readingLabel.font = kNormalFont;
    self.meaningLabel.font = kNormalFont;
  } else {
    self.readingLabel.font = item.readingWrong ? kIncorrectFont : kCorrectFont;
    self.meaningLabel.font = item.meaningWrong ? kIncorrectFont : kCorrectFont;
  }
  
  [self setShowAnswers:item.showAnswers animated:false];
}

- (void)setShowAnswers:(bool)showAnswers animated:(bool)animated {
  if (!animated) {
    _answerStack.hidden = !showAnswers;
    _answerStack.alpha = showAnswers ? 1.f : 0.f;
    return;
  }
  
  // Unhide the answer frame and update its width.
  _answerStack.hidden = NO;
  [self setNeedsLayout];
  [self layoutIfNeeded];
  
  CGRect visibleFrame = _answerStack.frame;
  CGRect hiddenFrame = visibleFrame;
  hiddenFrame.origin.x = self.frame.size.width;
  
  _answerStack.frame = showAnswers ? hiddenFrame : visibleFrame;
  _answerStack.alpha = showAnswers ? 0.f : 1.f;
  [UIView animateWithDuration:0.5f animations:^{
    _answerStack.frame = showAnswers ? visibleFrame : hiddenFrame;
    _answerStack.alpha = showAnswers ? 1.f : 0.f;
  } completion:^(BOOL finished) {
    _answerStack.hidden = showAnswers ? NO : YES;
  }];
}

- (void)didSelectCell {
  TKMSubjectModelItem *item = (TKMSubjectModelItem *)self.item;
  [item.delegate didTapSubject:item.subject];
}

@end

@interface TKMSubjectCollectionModelView : TKMModelCell
@end

@implementation TKMSubjectCollectionModelItem

- (instancetype)initWithSubjects:(GPBInt32Array *)subjects
                      dataLoader:(DataLoader *)dataLoader
                        delegate:(id<TKMSubjectChipDelegate>)delegate {
  self = [super init];
  if (self) {
    _subjects = subjects;
    _dataLoader = dataLoader;
    _delegate = delegate;
  }
  return self;
}

- (Class)cellClass {
  return TKMSubjectCollectionModelView.class;
}

@end

@implementation TKMSubjectCollectionModelView {
  NSMutableArray<TKMSubjectChip *> *_chips;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    _chips = [NSMutableArray array];
  }
  return self;
}

- (void)updateWithItem:(TKMSubjectCollectionModelItem *)item {
  [super updateWithItem:item];
  
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  
  // Remove all existing chips.
  for (TKMSubjectChip *chip in _chips) {
    [chip removeFromSuperview];
  }
  [_chips removeAllObjects];
  
  // Create a chip for each subject.
  for (int i = 0; i < item.subjects.count; ++i) {
    int subjectID = [item.subjects valueAtIndex:i];
    TKMSubject *subject = [item.dataLoader loadSubject:subjectID];
    TKMSubjectChip *chip = [[TKMSubjectChip alloc] initWithSubject:subject
                                                              font:item.font
                                                       showMeaning:true
                                                          delegate:item.delegate];
    [self.contentView addSubview:chip];
    [_chips addObject:chip];
  }
  [self setNeedsLayout];
}

- (void)layoutSubviews {
  NSArray<NSValue *> *chipFrames = TKMCalculateSubjectChipFrames(_chips, self.frame.size.width,
                                                                 NSTextAlignmentLeft);
  for (int i = 0; i < _chips.count; ++i) {
    _chips[i].frame = [chipFrames[i] CGRectValue];
  }
}

- (CGSize)sizeThatFits:(CGSize)size {
  if (!_chips.count) {
    return size;
  }
  NSArray<NSValue *> *chipFrames = TKMCalculateSubjectChipFrames(_chips, size.width,
                                                                 NSTextAlignmentLeft);
  return CGSizeMake(size.width,
                    CGRectGetMaxY([chipFrames.lastObject CGRectValue]) + kTKMSubjectChipCollectionEdgeInsets.bottom);
}

@end
