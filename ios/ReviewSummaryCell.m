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

#import "ReviewSummaryCell.h"
#import "Style.h"
#import "proto/Wanikani+Convenience.h"

@interface ReviewSummaryCell ()
@property (weak, nonatomic) IBOutlet UILabel *levelLabel;
@property (weak, nonatomic) IBOutlet UILabel *subjectLabel;
@property (weak, nonatomic) IBOutlet UILabel *readingLabel;
@property (weak, nonatomic) IBOutlet UILabel *meaningLabel;

@end

@implementation ReviewSummaryCell {
  UIFont *_normalFont;
  UIFont *_incorrectFont;
  __weak CAGradientLayer *_gradient;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _normalFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightThin];
    _incorrectFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightBold];
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

- (void)setSubject:(WKSubject *)subject {
  _subject = subject;
  _gradient.colors = WKGradientForSubject(subject);
  self.levelLabel.text = [NSString stringWithFormat:@"%d", subject.level];
  self.subjectLabel.attributedText = subject.japaneseText;
  if (subject.hasRadical) {
    [self.readingLabel setHidden:YES];
    self.meaningLabel.text = subject.commaSeparatedMeanings;
  } else if (subject.hasKanji) {
    [self.readingLabel setHidden:NO];
    self.readingLabel.text = subject.commaSeparatedPrimaryReadings;
    self.meaningLabel.text = subject.commaSeparatedMeanings;
  } else if (subject.hasVocabulary) {
    [self.readingLabel setHidden:NO];
    self.readingLabel.text = subject.commaSeparatedReadings;
    self.meaningLabel.text = subject.commaSeparatedMeanings;
  }
}

- (void)setItem:(ReviewItem *)item {
  _item = item;
  self.readingLabel.font = item.answer.readingWrong ? _incorrectFont : _normalFont;
  self.meaningLabel.font = item.answer.meaningWrong ? _incorrectFont : _normalFont;
}

@end
