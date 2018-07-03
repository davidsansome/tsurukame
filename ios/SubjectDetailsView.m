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

#import "NSMutableAttributedString+Replacements.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "UIColor+HexString.h"
#import "proto/Wanikani+Convenience.h"
#import "Tables/TKMAttributedModelItem.h"
#import "Tables/TKMMarkupModelItem.h"
#import "Tables/TKMTableModel.h"

NS_ASSUME_NONNULL_BEGIN

static const CGFloat kSectionHeaderHeight = 38.f;
static const CGFloat kSectionFooterHeight = 0.f;
static const CGFloat kFontSize = 14.f;

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

static NSAttributedString *RenderMeanings(NSArray<TKMMeaning *> *meanings,
                                          TKMStudyMaterials *studyMaterials) {
  NSMutableArray<NSAttributedString *> *strings = [NSMutableArray array];
  for (TKMMeaning *meaning in meanings) {
    if (meaning.isPrimary) {
      [strings addObject:[[NSAttributedString alloc] initWithString:meaning.meaning]];
    }
  }
  for (NSString *meaning in studyMaterials.meaningSynonymsArray) {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSForegroundColorAttributeName: kMeaningSynonymColor,
    };
    [strings addObject:[[NSAttributedString alloc] initWithString:meaning
                                                       attributes:attributes]];
  }
  for (TKMMeaning *meaning in meanings) {
    if (!meaning.isPrimary) {
      UIFont *font = [UIFont systemFontOfSize:kFont.pointSize weight:UIFontWeightLight];
      NSDictionary<NSAttributedStringKey, id> *attributes = @{
          NSFontAttributeName: font,
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
      [strings addObject:[[NSAttributedString alloc] initWithString:reading.reading]];
    }
  }
  for (TKMReading *reading in readings) {
    if (!primaryOnly && !reading.isPrimary) {
      UIFont *font = [UIFont systemFontOfSize:kFont.pointSize weight:UIFontWeightLight];
      NSDictionary<NSAttributedStringKey, id> *attributes = @{
          NSFontAttributeName: font,
      };
      [strings addObject:[[NSAttributedString alloc] initWithString:reading.reading
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
  
  TKMTableModel *_tableModel;
  
  __weak TKMSubjectChip *_lastSubjectChipTapped;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kMeaningSynonymColor = [UIColor colorWithRed:0.231 green:0.6 blue:0.988 alpha:1]; // #3b99fc
    kHintTextColor = [UIColor colorWithWhite:0.3f alpha:1.f];
    kFont = [UIFont systemFontOfSize:kFontSize];
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

- (void)addMeanings:(TKMSubject *)subject
     studyMaterials:(TKMStudyMaterials *)studyMaterials
            toModel:(TKMMutableTableModel *)model {
  NSAttributedString *text = RenderMeanings(subject.meaningsArray, studyMaterials);
  text = [text stringWithFontSize:kFontSize];
  TKMAttributedModelItem *item = [[TKMAttributedModelItem alloc] initWithText:text];
  
  [model addSection:@"Meaning"];
  [model addItem:item];
}

- (void)addReadings:(TKMSubject *)subject
            toModel:(TKMMutableTableModel *)model {
  bool primaryOnly = subject.hasKanji;
  NSAttributedString *text = RenderReadings(subject.readingsArray, primaryOnly);
  text = [text stringWithFontSize:kFontSize];
  TKMAttributedModelItem *item = [[TKMAttributedModelItem alloc] initWithText:text];
  
  [model addSection:@"Reading"];
  [model addItem:item];
}

- (void)addComponents:(TKMSubject *)subject
                title:(NSString *)title
              toModel:(TKMMutableTableModel *)model {
  TKMSubjectCollectionModelItem *item = [[TKMSubjectCollectionModelItem alloc]
      initWithSubjects:subject.componentSubjectIdsArray
            dataLoader:_dataLoader
              delegate:self];
  item.font = kFont;
  
  [model addSection:title];
  [model addItem:item];
}

- (void)addAmalgamationSubjects:(TKMSubject *)subject
                        toModel:(TKMMutableTableModel *)model {
  if (!subject.amalgamationSubjectIdsArray.count) {
    return;
  }
  [model addSection:@"Used in"];
  for (int i = 0; i < subject.amalgamationSubjectIdsArray.count; ++i) {
    int subjectID = [subject.amalgamationSubjectIdsArray valueAtIndex:i];
    TKMSubject *subject = [_dataLoader loadSubject:subjectID];
    [model addItem:[[TKMSubjectModelItem alloc] initWithSubject:subject delegate:_subjectDelegate]];
  }
}

- (void)addFormattedText:(NSArray<TKMFormattedText*> *)formattedText
                  isHint:(bool)isHint
                 toModel:(TKMMutableTableModel *)model {
  if (isHint && !_showHints) {
    return;
  }
  
  NSMutableAttributedString *text = TKMRenderFormattedText(formattedText);
  [text replaceFontSize:kFontSize];
  if (isHint) {
    [text replaceTextColor:kHintTextColor];
  }
  
  [model addItem:[[TKMAttributedModelItem alloc] initWithText:text]];
}

- (void)addContextSentences:(TKMSubject *)subject
                    toModel:(TKMMutableTableModel *)model {
  if (!subject.vocabulary.sentencesArray.count) {
    return;
  }
  
  [model addSection:@"Context Sentences"];
  for (TKMVocabulary_Sentence *sentence in subject.vocabulary.sentencesArray) {
    TKMBasicModelItem *item = [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                                 title:sentence.japanese
                                                              subtitle:sentence.english];
    item.titleFont = kFont;
    item.subtitleFont = kFont;
    item.numberOfTitleLines = 0;
    item.numberOfSubtitleLines = 0;
    [model addItem:item];
  }
}

- (void)updateWithSubject:(TKMSubject *)subject
           studyMaterials:(TKMStudyMaterials *)studyMaterials
               assignment:(nullable TKMAssignment *)assignment {
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self];
  
  if (subject.hasRadical) {
    [self addMeanings:subject studyMaterials:studyMaterials toModel:model];

    [model addSection:@"Mnemonic"];
    [self addFormattedText:subject.radical.formattedMnemonicArray isHint:false toModel:model];
    
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
    
    [self addAmalgamationSubjects:subject toModel:model];
  }
  if (subject.hasVocabulary) {
    [self addMeanings:subject studyMaterials:studyMaterials toModel:model];
    [self addReadings:subject toModel:model];
    [self addComponents:subject title:@"Kanji" toModel:model];
    
    [model addSection:@"Meaning Explanation"];
    [self addFormattedText:subject.vocabulary.formattedMeaningExplanationArray isHint:false toModel:model];
    
    [model addSection:@"Reading Explanation"];
    [self addFormattedText:subject.vocabulary.formattedReadingExplanationArray isHint:false toModel:model];
    
    [self addContextSentences:subject toModel:model];
    
    // TODO: part of speech
    
  }
  
  // TODO: Your progress, SRS level, next review, first started, reached guru
  
  _tableModel = model;
  [model reloadTable];
}

- (void)deselectLastSubjectChipTapped {
  _lastSubjectChipTapped.backgroundColor = nil;
}

#pragma mark - TKMSubjectChipDelegate

- (void)didTapSubjectChip:(TKMSubjectChip *)chip {
  _lastSubjectChipTapped = chip;
  
  _lastSubjectChipTapped.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.f];
  [_subjectDelegate didTapSubject:_lastSubjectChipTapped.subject];
}

@end

NS_ASSUME_NONNULL_END

