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

#import <UIKit/UIKit.h>

#import "UserDefaults.h"
#import "Wanikani+Convenience.h"

static const int kGuruStage = 5;

NSString *TKMSubjectTypeName(TKMSubject_Type subjectType) {
  switch (subjectType) {
    case TKMSubject_Type_Radical:
      return @"Radical";
    case TKMSubject_Type_Kanji:
      return @"Kanji";
    case TKMSubject_Type_Vocabulary:
      return @"Vocabulary";
  }
}

TKMSRSStageCategory TKMSRSStageCategoryForStage(int srsStage) {
  switch (srsStage) {
    case 1:
      return TKMSRSStageNovice;
    case 2:
    case 3:
    case 4:
      return TKMSRSStageApprentice;
    case 5:
    case 6:
      return TKMSRSStageGuru;
    case 7:
      return TKMSRSStageMaster;
    case 8:
      return TKMSRSStageEnlightened;
    case 9:
      return TKMSRSStageBurned;
    default:
      return TKMSRSStageNovice;
  }
}

int TKMSRSStageCategoryIntForStage(int srsStage) {
  switch (srsStage) {
    case 1:
      return 0;
    case 2:
    case 3:
    case 4:
      return 1;
    case 5:
    case 6:
      return 2;
    case 7:
      return 3;
    case 8:
      return 4;
    case 9:
      return 5;
    default:
      return 0;
  }
}

NSString *TKMSRSStageName(int srsStage) {
  switch (srsStage) {
    case 1:
      return @"Novice";
    case 2:
    case 3:
    case 4:
      return @"Apprentice";
    case 5:
    case 6:
      return @"Guru";
    case 7:
      return @"Master";
    case 8:
      return @"Enlightened";
    case 9:
      return @"Burned";
  }
  return nil;
}

NSString *TKMDetailedSRSStageName(int srsStage) {
  switch (srsStage) {
    case 1:
      return @"Novice";
    case 2:
      return @"Apprentice I";
    case 3:
      return @"Apprentice II";
    case 4:
      return @"Apprentice III";
    case 5:
      return @"Guru I";
    case 6:
      return @"Guru II";
    case 7:
      return @"Master";
    case 8:
      return @"Enlightened";
    case 9:
      return @"Burned";
  }
  return nil;
}

NSTimeInterval TKMMinimumTimeUntilGuruSeconds(int itemLevel, int srsStage) {
  const bool isAccelerated = itemLevel <= 2;

  int hours = 0;
  // From https://docs.api.wanikani.com/20170710/#additional-information
  switch (srsStage) {
    case 1:
      hours += (isAccelerated ? 2 : 4);
    case 2:
      hours += (isAccelerated ? 4 : 8);
    case 3:
      hours += (isAccelerated ? 8 : 23);
    case 4:
      hours += (isAccelerated ? 23 : 47);
  }
  return hours * 60 * 60;
}

@implementation TKMSubject (Convenience)

- (NSAttributedString *)japaneseText {
  return [self japaneseTextWithImageSize:0];
}

- (NSAttributedString *)japaneseTextWithImageSize:(CGFloat)imageSize {
  if (!self.hasRadical || !self.radical.hasCharacterImageFile) {
    return [[NSAttributedString alloc] initWithString:self.japanese];
  }

  NSTextAttachment *imageAttachment = [[NSTextAttachment alloc] init];
  imageAttachment.image = [UIImage imageNamed:[NSString stringWithFormat:@"radical-%d", self.id_p]];
  if (imageSize == 0) {
    imageSize = imageAttachment.image.size.width;
  }
  imageAttachment.bounds = CGRectMake(0, 0, imageSize, imageSize);
  return [NSAttributedString attributedStringWithAttachment:imageAttachment];
}

- (NSString *)subjectTypeString {
  if (self.hasRadical) {
    return @"radical";
  }
  if (self.hasKanji) {
    return @"kanji";
  }
  if (self.hasVocabulary) {
    return @"vocabulary";
  }
  return nil;
}

- (TKMSubject_Type)subjectType {
  if (self.hasRadical) {
    return TKMSubject_Type_Radical;
  }
  if (self.hasKanji) {
    return TKMSubject_Type_Kanji;
  }
  if (self.hasVocabulary) {
    return TKMSubject_Type_Vocabulary;
  }
  abort();
}

- (NSString *)primaryMeaning {
  for (TKMMeaning *meaning in self.meaningsArray) {
    if (meaning.type == TKMMeaning_Type_Primary) {
      return meaning.meaning;
    }
  }
  return nil;
}

- (NSArray<TKMReading *> *)primaryReadings {
  return [self readingsFilteredByPrimary:YES];
}

- (NSArray<TKMReading *> *)alternateReadings {
  return [self readingsFilteredByPrimary:NO];
}

- (NSArray<TKMReading *> *)readingsFilteredByPrimary:(BOOL)primary {
  NSMutableArray<TKMReading *> *ret = [NSMutableArray array];
  for (TKMReading *reading in self.readingsArray) {
    if (reading.isPrimary == primary) {
      [ret addObject:reading];
    }
  }
  return ret;
}

- (NSString *)commaSeparatedMeanings {
  NSMutableArray<NSString *> *strings = [NSMutableArray array];
  for (TKMMeaning *meaning in self.meaningsArray) {
    if (meaning.type != TKMMeaning_Type_Blacklist &&
        (meaning.type != TKMMeaning_Type_AuxiliaryWhitelist || !self.hasRadical ||
         UserDefaults.showOldMnemonic)) {
      [strings addObject:meaning.meaning];
    }
  }
  return [strings componentsJoinedByString:@", "];
}

- (NSString *)commaSeparatedReadings {
  NSMutableArray<NSString *> *strings = [NSMutableArray array];
  for (TKMReading *reading in self.readingsArray) {
    [strings addObject:reading.reading];
  }
  return [strings componentsJoinedByString:@", "];
}

- (NSString *)commaSeparatedPrimaryReadings {
  NSMutableArray<NSString *> *strings = [NSMutableArray array];
  for (TKMReading *reading in self.primaryReadings) {
    [strings addObject:reading.displayText];
  }
  return [strings componentsJoinedByString:@", "];
}

- (int)randomAudioID {
  if (!self.hasVocabulary || self.vocabulary.audioIdsArray_Count < 1) {
    return 0;
  }

  uint idx = arc4random_uniform((uint)self.vocabulary.audioIdsArray_Count);
  return [self.vocabulary.audioIdsArray valueAtIndex:idx];
}

@end

@implementation TKMReading (Convenience)

- (NSString *)displayText {
  if (self.hasType && self.type == TKMReading_Type_Onyomi && UserDefaults.useKatakanaForOnyomi) {
    return [self.reading stringByApplyingTransform:NSStringTransformHiraganaToKatakana reverse:NO];
  }
  return self.reading;
}

@end

@implementation TKMVocabulary (Convenience)

- (NSString *)commaSeparatedPartsOfSpeech {
  NSMutableArray<NSString *> *parts = [NSMutableArray array];
  [self.partsOfSpeechArray
      enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL *_Nonnull stop) {
        NSString *str;
        switch ((TKMVocabulary_PartOfSpeech)value) {
          case TKMVocabulary_PartOfSpeech_Noun:
            str = @"Noun";
            break;
          case TKMVocabulary_PartOfSpeech_Numeral:
            str = @"Numeral";
            break;
          case TKMVocabulary_PartOfSpeech_IntransitiveVerb:
            str = @"Intransitive Verb";
            break;
          case TKMVocabulary_PartOfSpeech_IchidanVerb:
            str = @"Ichidan Verb";
            break;
          case TKMVocabulary_PartOfSpeech_TransitiveVerb:
            str = @"Transitive Verb";
            break;
          case TKMVocabulary_PartOfSpeech_NoAdjective:
            str = @"No Adjective";
            break;
          case TKMVocabulary_PartOfSpeech_GodanVerb:
            str = @"Godan Verb";
            break;
          case TKMVocabulary_PartOfSpeech_NaAdjective:
            str = @"Na Adjective";
            break;
          case TKMVocabulary_PartOfSpeech_IAdjective:
            str = @"I Adjective";
            break;
          case TKMVocabulary_PartOfSpeech_Suffix:
            str = @"Suffix";
            break;
          case TKMVocabulary_PartOfSpeech_Adverb:
            str = @"Adverb";
            break;
          case TKMVocabulary_PartOfSpeech_SuruVerb:
            str = @"Suru Verb";
            break;
          case TKMVocabulary_PartOfSpeech_Prefix:
            str = @"Prefix";
            break;
          case TKMVocabulary_PartOfSpeech_ProperNoun:
            str = @"Proper Noun";
            break;
          case TKMVocabulary_PartOfSpeech_Expression:
            str = @"Expression";
            break;
          case TKMVocabulary_PartOfSpeech_Adjective:
            str = @"Adjective";
            break;
          case TKMVocabulary_PartOfSpeech_Interjection:
            str = @"Interjection";
            break;
          case TKMVocabulary_PartOfSpeech_Counter:
            str = @"Counter";
            break;
          case TKMVocabulary_PartOfSpeech_Pronoun:
            str = @"Pronoun";
            break;
          case TKMVocabulary_PartOfSpeech_Conjunction:
            str = @"Conjunction";
            break;
        }
        [parts addObject:str];
      }];
  return [parts componentsJoinedByString:@", "];
}

- (bool)isVerb {
  for (int i = 0; i < self.partsOfSpeechArray.count; ++i) {
    switch ([self.partsOfSpeechArray valueAtIndex:i]) {
      case TKMVocabulary_PartOfSpeech_GodanVerb:
      case TKMVocabulary_PartOfSpeech_IchidanVerb:
      case TKMVocabulary_PartOfSpeech_SuruVerb:
      case TKMVocabulary_PartOfSpeech_TransitiveVerb:
      case TKMVocabulary_PartOfSpeech_IntransitiveVerb:
        return true;
      default:
        break;
    }
  }
  return false;
}

@end

@implementation TKMAssignment (Convenience)

- (bool)isLessonStage {
  return !self.isLocked && !self.hasStartedAt && self.srsStage == 0;
}

- (bool)isReviewStage {
  return !self.isLocked && self.hasAvailableAt;
}

- (bool)isBurned {
  return self.srsStage == 9;
}

- (bool)isLocked {
  return !self.hasSrsStage;
}

- (NSDate *)availableAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.availableAt];
}

- (NSDate *)startedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.startedAt];
}

- (NSDate *)passedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.passedAt];
}

- (NSDate *)reviewDate {
  if (self.isBurned || self.isLocked) {
    return nil;
  }

  // If it's available now, treat it like it will be reviewed this hour.
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [calendar
      components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour)
        fromDate:[NSDate date]];
  NSDate *reviewDate = [calendar dateFromComponents:components];

  if (!self.hasAvailableAt) {
    return reviewDate;
  }

  // If it's not available now, treat it like it will be reviewed within the hour it comes
  // available.
  if ([reviewDate compare:self.availableAtDate] == NSOrderedAscending) {
    reviewDate = self.availableAtDate;
  }
  return reviewDate;
}

- (NSDate *)guruDateForSubject:(TKMSubject *)subject {
  if (self.hasPassedAt) {
    return self.passedAtDate;
  }
  if (self.srsStage >= kGuruStage) {
    return [NSDate distantPast];
  }

  NSDate *reviewDate = [self reviewDate];
  int guruSeconds = TKMMinimumTimeUntilGuruSeconds(subject.level, self.srsStage + 1);
  return [reviewDate dateByAddingTimeInterval:guruSeconds];
}

@end

@implementation TKMProgress (Convenience)

- (NSString *)reviewFormParameters {
  return [NSString stringWithFormat:@"%d%%5B%%5D=%@&%d%%5B%%5D=%@",
                                    self.assignment.subjectId,
                                    self.hasMeaningWrong ? (self.meaningWrong ? @"1" : @"0") : @"",
                                    self.assignment.subjectId,
                                    self.hasReadingWrong ? (self.readingWrong ? @"1" : @"0") : @""];
}

- (NSString *)lessonFormParameters {
  return [NSString stringWithFormat:@"keys%%5B%%5D=%d", self.assignment.subjectId];
}

- (NSDate *)createdAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.createdAt];
}

@end

@implementation TKMUser (Convenience)

- (NSDate *)startedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.startedAt];
}

- (int)currentLevel {
  return MIN(self.level, self.maxLevelGrantedBySubscription);
}

@end

@implementation TKMLevel (Convenience)

- (NSDate *)unlockedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.unlockedAt];
}

- (NSDate *)startedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.startedAt];
}

- (NSDate *)passedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.passedAt];
}

- (NSDate *)abandonedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.abandonedAt];
}

- (NSDate *)completedAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.completedAt];
}

- (NSDate *)createdAtDate {
  return [NSDate dateWithTimeIntervalSince1970:self.createdAt];
}

- (NSTimeInterval)timeSpentCurrent {
  if (!self.hasUnlockedAt) {
    return 0;
  }

  NSDate *startDate = self.hasStartedAt ? [self startedAtDate] : [self unlockedAtDate];
  if (self.hasPassedAt) {
    return [[self passedAtDate] timeIntervalSinceDate:startDate];
  } else {
    return [[NSDate date] timeIntervalSinceDate:startDate];
  }
}

@end
