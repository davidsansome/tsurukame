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

#import "SubjectDetailsView.h"

#import "LocalCachingClient.h"
#import "NSMutableAttributedString+Replacements.h"
#import "Settings.h"
#import "Style.h"
#import "SubjectDetailsViewController.h"
#import "TKMAudio.h"
#import "TKMServices.h"
#import "Tables/TKMAttributedModelItem.h"
#import "Tables/TKMMarkupModelItem.h"
#import "Tables/TKMReadingModelItem.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"
#import "UIColor+HexString.h"
#import "proto/Wanikani+Convenience.h"

NS_ASSUME_NONNULL_BEGIN

static const CGFloat kSectionHeaderHeight = 38.f;
static const CGFloat kSectionFooterHeight = 0.f;
static const CGFloat kFontSize = 14.f;

static const int kVisuallySimilarKanjiScoreThreshold = 400;

static UIColor *kMeaningSynonymColor;
static UIColor *kHintTextColor;
static UIFont *kFont;

static NSAttributedString *JoinAttributedStringArray(NSArray<NSAttributedString *> *strings,
                                                     NSString *join) {
  NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] init];
  const NSUInteger count = strings.count;
  for (NSUInteger i = 0; i < count; ++i) {
    [ret appendAttributedString:strings[i]];
    if (i != count - 1) {
      [ret appendAttributedString:[[NSAttributedString alloc] initWithString:join]];
    }
  }
  return ret;
}

static NSAttributedString *RenderMeanings(TKMSubject *subject, TKMStudyMaterials *studyMaterials) {
  NSMutableArray<NSAttributedString *> *strings = [NSMutableArray array];
  for (TKMMeaning *meaning in subject.meaningsArray) {
    if (meaning.type == TKMMeaning_Type_Primary) {
      [strings addObject:[[NSAttributedString alloc] initWithString:meaning.meaning]];
    }
  }
  for (NSString *meaning in studyMaterials.meaningSynonymsArray) {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
      NSForegroundColorAttributeName : kMeaningSynonymColor,
    };
    [strings addObject:[[NSAttributedString alloc] initWithString:meaning attributes:attributes]];
  }
  for (TKMMeaning *meaning in subject.meaningsArray) {
    if (meaning.type != TKMMeaning_Type_Primary && meaning.type != TKMMeaning_Type_Blacklist &&
        (meaning.type != TKMMeaning_Type_AuxiliaryWhitelist || !subject.hasRadical ||
         Settings.showOldMnemonic)) {
      UIFont *font = [UIFont systemFontOfSize:kFont.pointSize weight:UIFontWeightLight];
      NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName : font,
      };
      [strings addObject:[[NSAttributedString alloc] initWithString:meaning.meaning
                                                         attributes:attributes]];
    }
  }
  return JoinAttributedStringArray(strings, @", ");
}

static NSAttributedString *RenderReadings(NSArray<TKMReading *> *readings, bool primaryOnly) {
  NSMutableArray<NSAttributedString *> *strings = [NSMutableArray array];
  for (TKMReading *reading in readings) {
    if (reading.isPrimary) {
      [strings addObject:[[NSAttributedString alloc] initWithString:reading.displayText]];
    }
  }
  for (TKMReading *reading in readings) {
    if (!primaryOnly && !reading.isPrimary) {
      UIFont *font = TKMJapaneseFontLight(kFontSize);
      NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName : font,
      };
      [strings addObject:[[NSAttributedString alloc] initWithString:reading.displayText
                                                         attributes:attributes]];
    }
  }
  return JoinAttributedStringArray(strings, @", ");
}

@interface TKMSubjectDetailsView () <TKMSubjectChipDelegate>
@end

@implementation TKMSubjectDetailsView {
  NSDateFormatter *_availableDateFormatter;
  NSDateFormatter *_startedDateFormatter;

  TKMServices *_services;
  BOOL _showHints;
  __weak id<TKMSubjectDelegate> _subjectDelegate;

  TKMTableModel *_tableModel;
  TKMReadingModelItem *_readingItem;

  __weak TKMSubjectChip *_lastSubjectChipTapped;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kMeaningSynonymColor = [UIColor colorWithRed:0.231 green:0.6 blue:0.988 alpha:1];  // #3b99fc
    kHintTextColor = [UIColor colorWithWhite:0.3f alpha:1.f];
    kFont = TKMJapaneseFont(kFontSize);
  });

  self = [super initWithCoder:coder];
  if (self) {
    _availableDateFormatter = [[NSDateFormatter alloc] init];
    _availableDateFormatter.dateStyle = NSDateFormatterMediumStyle;
    _availableDateFormatter.timeStyle = NSDateFormatterMediumStyle;

    _startedDateFormatter = [[NSDateFormatter alloc] init];
    _startedDateFormatter.dateStyle = NSDateFormatterMediumStyle;
    _startedDateFormatter.timeStyle = NSDateFormatterNoStyle;

    self.sectionHeaderHeight = kSectionHeaderHeight;
    self.estimatedSectionHeaderHeight = kSectionHeaderHeight;
    self.sectionFooterHeight = kSectionFooterHeight;
    self.estimatedSectionFooterHeight = kSectionFooterHeight;
  }
  return self;
}

- (void)setupWithServices:(TKMServices *)services
                showHints:(BOOL)showHints
          subjectDelegate:(id<TKMSubjectDelegate>)subjectDelegate {
  _services = services;
  _showHints = showHints;
  _subjectDelegate = subjectDelegate;
}

- (void)addMeanings:(TKMSubject *)subject
     studyMaterials:(TKMStudyMaterials *)studyMaterials
            toModel:(TKMMutableTableModel *)model {
  NSAttributedString *text = RenderMeanings(subject, studyMaterials);
  text = [text stringWithFontSize:kFontSize];
  TKMAttributedModelItem *item = [[TKMAttributedModelItem alloc] initWithText:text];

  [model addSection:@"Meaning"];
  [model addItem:item];
}

- (void)addReadings:(TKMSubject *)subject toModel:(TKMMutableTableModel *)model {
  bool primaryOnly = subject.hasKanji;
  NSAttributedString *text = RenderReadings(subject.readingsArray, primaryOnly);
  text = [text stringWithFontSize:kFontSize];
  TKMReadingModelItem *item = [[TKMReadingModelItem alloc] initWithText:text];
  if (subject.hasVocabulary && subject.vocabulary.audioIdsArray_Count > 0) {
    [item setAudio:_services.audio subjectID:subject.id_p];
  }

  _readingItem = item;
  [model addSection:@"Reading"];
  [model addItem:item];
}

- (void)addComponents:(TKMSubject *)subject
                title:(NSString *)title
              toModel:(TKMMutableTableModel *)model {
  TKMSubjectCollectionModelItem *item =
      [[TKMSubjectCollectionModelItem alloc] initWithSubjects:subject.componentSubjectIdsArray
                                                   dataLoader:_services.dataLoader
                                                     delegate:self];

  [model addSection:title];
  [model addItem:item];
}

- (void)addSimilarKanji:(TKMSubject *)subject toModel:(TKMMutableTableModel *)model {
  int currentLevel = [_services.localCachingClient getUserInfo].level;
  bool addedSection = false;
  for (TKMVisuallySimilarKanji *visuallySimilarKanji in subject.kanji.visuallySimilarKanjiArray) {
    if (visuallySimilarKanji.score < kVisuallySimilarKanjiScoreThreshold) {
      continue;
    }
    TKMSubject *subject = [_services.dataLoader loadSubject:visuallySimilarKanji.id_p];
    if (!subject || subject.level > currentLevel) {
      continue;
    }
    if (!addedSection) {
      [model addSection:@"Visually Similar Kanji"];
      addedSection = true;
    }

    TKMSubjectModelItem *item = [[TKMSubjectModelItem alloc] initWithSubject:subject
                                                                    delegate:_subjectDelegate];
    [model addItem:item];
  }
}

- (void)addAmalgamationSubjects:(TKMSubject *)subject toModel:(TKMMutableTableModel *)model {
  NSMutableArray<TKMSubject *> *amalgamationSubjects = [NSMutableArray array];
  for (int i = 0; i < subject.amalgamationSubjectIdsArray_Count; ++i) {
    int subjectID = [subject.amalgamationSubjectIdsArray valueAtIndex:i];
    TKMSubject *amalgamationSubject = [_services.dataLoader loadSubject:subjectID];
    if (amalgamationSubject) {
      [amalgamationSubjects addObject:amalgamationSubject];
    }
  }

  if (!amalgamationSubjects.count) {
    return;
  }

  [model addSection:@"Used in"];
  for (TKMSubject *amalgamationSubject in amalgamationSubjects) {
    [model addItem:[[TKMSubjectModelItem alloc] initWithSubject:amalgamationSubject
                                                       delegate:_subjectDelegate]];
  }
}

- (void)addFormattedText:(NSArray<TKMFormattedText *> *)formattedText
                  isHint:(bool)isHint
                 toModel:(TKMMutableTableModel *)model {
  if (isHint && !_showHints) {
    return;
  }
  if (!formattedText.count) {
    return;
  }

  NSDictionary<NSAttributedStringKey, id> *standardAttributes;
  if (isHint) {
    standardAttributes = @{NSForegroundColorAttributeName : kHintTextColor};
  }

  NSMutableAttributedString *text = TKMRenderFormattedText(formattedText, standardAttributes);
  [text replaceFontSize:kFontSize];

  [model addItem:[[TKMAttributedModelItem alloc] initWithText:text]];
}

- (void)addContextSentences:(TKMSubject *)subject toModel:(TKMMutableTableModel *)model {
  if (!subject.vocabulary.sentencesArray.count) {
    return;
  }

  [model addSection:@"Context Sentences"];
  for (TKMVocabulary_Sentence *sentence in subject.vocabulary.sentencesArray) {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:TKMJapaneseFont(kFontSize) forKey:NSFontAttributeName];
    NSMutableAttributedString *japanese =
        [[NSMutableAttributedString alloc] initWithString:sentence.japanese attributes:attributes];

    // Highlight occurences of this subject in the Japanese text.
    NSString *textToHighlight = subject.japanese;
    if (subject.vocabulary.isVerb) {
      textToHighlight =
          [textToHighlight stringByTrimmingCharactersInSet:AnswerChecker.kKanaCharacterSet];
    }
    NSUInteger startPos = 0;
    while (true) {
      NSRange searchRange = NSMakeRange(startPos, sentence.japanese.length - startPos);
      NSRange highlightRange = [sentence.japanese rangeOfString:textToHighlight
                                                        options:0
                                                          range:searchRange];
      if (highlightRange.location == NSNotFound) {
        break;
      }
      [japanese addAttribute:NSForegroundColorAttributeName
                       value:[UIColor redColor]
                       range:highlightRange];
      startPos = highlightRange.location + highlightRange.length;
    }

    [text appendAttributedString:japanese];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:sentence.english]];
    [text replaceFontSize:kFontSize];

    TKMAttributedModelItem *item = [[TKMAttributedModelItem alloc] initWithText:text];
    [model addItem:item];
  }
}

- (void)addPartsOfSpeech:(TKMVocabulary *)vocab toModel:(TKMMutableTableModel *)model {
  NSString *text = [vocab commaSeparatedPartsOfSpeech];
  if (!text.length) {
    return;
  }

  [model addSection:@"Part of Speech"];
  TKMBasicModelItem *item = [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                               title:text
                                                            subtitle:nil];
  item.titleFont = [UIFont systemFontOfSize:kFontSize];
  [model addItem:item];
}

- (void)updateWithSubject:(TKMSubject *)subject
           studyMaterials:(nullable TKMStudyMaterials *)studyMaterials {
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self];
  _readingItem = nil;

  if (subject.hasRadical) {
    [self addMeanings:subject studyMaterials:studyMaterials toModel:model];

    [model addSection:@"Mnemonic"];
    [self addFormattedText:subject.radical.formattedMnemonicArray isHint:false toModel:model];

    if (Settings.showOldMnemonic && subject.radical.formattedDeprecatedMnemonicArray_Count) {
      [model addSection:@"Old Mnemonic"];
      [self addFormattedText:subject.radical.formattedDeprecatedMnemonicArray
                      isHint:false
                     toModel:model];
    }

    [self addAmalgamationSubjects:subject toModel:model];
  }
  if (subject.hasKanji) {
    [self addMeanings:subject studyMaterials:studyMaterials toModel:model];
    [self addReadings:subject toModel:model];
    [self addComponents:subject title:@"Radicals" toModel:model];

    [model addSection:@"Meaning Explanation"];
    [self addFormattedText:subject.kanji.formattedMeaningMnemonicArray isHint:false toModel:model];
    [self addFormattedText:subject.kanji.formattedMeaningHintArray isHint:true toModel:model];

    [model addSection:@"Reading Explanation"];
    [self addFormattedText:subject.kanji.formattedReadingMnemonicArray isHint:false toModel:model];
    [self addFormattedText:subject.kanji.formattedReadingHintArray isHint:true toModel:model];

    [self addSimilarKanji:subject toModel:model];
    [self addAmalgamationSubjects:subject toModel:model];
  }
  if (subject.hasVocabulary) {
    [self addMeanings:subject studyMaterials:studyMaterials toModel:model];
    [self addReadings:subject toModel:model];
    [self addComponents:subject title:@"Kanji" toModel:model];

    [model addSection:@"Meaning Explanation"];
    [self addFormattedText:subject.vocabulary.formattedMeaningExplanationArray
                    isHint:false
                   toModel:model];

    [model addSection:@"Reading Explanation"];
    [self addFormattedText:subject.vocabulary.formattedReadingExplanationArray
                    isHint:false
                   toModel:model];

    [self addPartsOfSpeech:subject.vocabulary toModel:model];
    [self addContextSentences:subject toModel:model];
  }

  // TODO: Your progress, SRS level, next review, first started, reached guru

  _tableModel = model;
  [model reloadTable];
}

- (void)deselectLastSubjectChipTapped {
  _lastSubjectChipTapped.backgroundColor = nil;
}

- (void)playAudio {
  [_readingItem playAudio];
}

#pragma mark - TKMSubjectChipDelegate

- (void)didTapSubjectChip:(TKMSubjectChip *)chip {
  _lastSubjectChipTapped = chip;

  _lastSubjectChipTapped.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.f];
  [_subjectDelegate didTapSubject:_lastSubjectChipTapped.subject];
}

@end

NS_ASSUME_NONNULL_END
