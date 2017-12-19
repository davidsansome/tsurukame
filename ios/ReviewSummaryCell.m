#import "ReviewSummaryCell.h"
#import "proto/Wanikani+Convenience.h"

@interface ReviewSummaryCell ()
@property (weak, nonatomic) IBOutlet UILabel *subjectLabel;
@property (weak, nonatomic) IBOutlet UILabel *readingLabel;
@property (weak, nonatomic) IBOutlet UILabel *meaningLabel;

@end

@implementation ReviewSummaryCell

- (void)setSubject:(WKSubject *)subject {
  _subject = subject;
  self.subjectLabel.text = subject.japanese;
  if (subject.hasRadical) {
    [self.readingLabel setHidden:YES];
    self.meaningLabel.text = subject.radical.commaSeparatedMeanings;
  } else if (subject.hasKanji) {
    [self.readingLabel setHidden:NO];
    self.readingLabel.text = subject.kanji.commaSeparatedReadings;
    self.meaningLabel.text = subject.kanji.commaSeparatedMeanings;
  } else if (subject.hasVocabulary) {
    [self.readingLabel setHidden:NO];
    self.readingLabel.text = subject.vocabulary.commaSeparatedReadings;
    self.meaningLabel.text = subject.vocabulary.commaSeparatedMeanings;
  }
}

- (void)setItem:(ReviewItem *)item {
  _item = item;
  self.readingLabel.textColor = item.answer.readingWrong ? [UIColor redColor] : [UIColor blackColor];
  self.meaningLabel.textColor = item.answer.meaningWrong ? [UIColor redColor] : [UIColor blackColor];
}

@end
