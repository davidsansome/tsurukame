#import "ReviewSummaryCell.h"
#import "Style.h"
#import "proto/Wanikani+Convenience.h"

@interface ReviewSummaryCell ()
@property (weak, nonatomic) IBOutlet UILabel *subjectLabel;
@property (weak, nonatomic) IBOutlet UILabel *readingLabel;
@property (weak, nonatomic) IBOutlet UILabel *meaningLabel;

@end

@implementation ReviewSummaryCell {
  UIFont *_normalFont;
  UIFont *_incorrectFont;
  CAGradientLayer *_gradient;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _normalFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightThin];
    _incorrectFont = [UIFont systemFontOfSize:14.0f weight:UIFontWeightBold];
    _gradient = [CAGradientLayer layer];
    [self.contentView.layer insertSublayer:_gradient atIndex:0];
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
  self.subjectLabel.attributedText = subject.japaneseText;
  if (subject.hasRadical) {
    [self.readingLabel setHidden:YES];
    self.meaningLabel.text = subject.commaSeparatedMeanings;
  } else if (subject.hasKanji || subject.hasVocabulary) {
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
