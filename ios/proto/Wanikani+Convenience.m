//
//  Wanikani+Convenience.m
//  wk
//
//  Created by David Sansome on 28/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "Wanikani+Convenience.h"

@implementation WKSubject (Convenience)

- (NSString *)primaryMeaning {
  for (WKMeaning *meaning in self.meaningsArray) {
    if (meaning.isPrimary) {
      return meaning.meaning;
    }
  }
  return nil;
}

- (NSArray<WKReading *> *)primaryReadings {
  return [self readingsFilteredByPrimary:YES];
}

- (NSArray<WKReading *> *)alternateReadings {
  return [self readingsFilteredByPrimary:NO];
}

- (NSArray<WKReading *> *)readingsFilteredByPrimary:(BOOL)primary {
  NSMutableArray<WKReading *> *ret = [NSMutableArray array];
  for (WKReading *reading in self.readingsArray) {
    if (reading.isPrimary == primary) {
      [ret addObject:reading];
    }
  }
  return ret;
}

- (NSString *)commaSeparatedMeanings {
  NSMutableArray<NSString *>* strings = [NSMutableArray array];
  for (WKMeaning *meaning in self.meaningsArray) {
    [strings addObject:meaning.meaning];
  }
  return [strings componentsJoinedByString:@", "];
}

- (NSString *)commaSeparatedReadings {
  NSMutableArray<NSString *>* strings = [NSMutableArray array];
  for (WKReading *reading in self.readingsArray) {
    [strings addObject:reading.reading];
  }
  return [strings componentsJoinedByString:@", "];
}

@end

@implementation WKVocabulary (Convenience)

- (NSString *)commaSeparatedPartsOfSpeech {
  NSMutableArray<NSString *> *parts = [NSMutableArray array];
  [self.partsOfSpeechArray enumerateValuesWithBlock:^(int32_t value, NSUInteger idx, BOOL * _Nonnull stop) {
    NSString *str;
    switch ((WKVocabulary_PartOfSpeech)value) {
      case WKVocabulary_PartOfSpeech_Noun:             str = @"Noun";              break;
      case WKVocabulary_PartOfSpeech_Numeral:          str = @"Numeral";           break;
      case WKVocabulary_PartOfSpeech_IntransitiveVerb: str = @"Intransitive Verb"; break;
      case WKVocabulary_PartOfSpeech_IchidanVerb:      str = @"Ichidan Verb";      break;
      case WKVocabulary_PartOfSpeech_TransitiveVerb:   str = @"Transitive Verb";   break;
      case WKVocabulary_PartOfSpeech_NoAdjective:      str = @"No Adjective";      break;
      case WKVocabulary_PartOfSpeech_GodanVerb:        str = @"Godan Verb";        break;
      case WKVocabulary_PartOfSpeech_NaAdjective:      str = @"Na Adjective";      break;
      case WKVocabulary_PartOfSpeech_IAdjective:       str = @"I Adjective";       break;
      case WKVocabulary_PartOfSpeech_Suffix:           str = @"Suffix";            break;
      case WKVocabulary_PartOfSpeech_Adverb:           str = @"Adverb";            break;
      case WKVocabulary_PartOfSpeech_SuruVerb:         str = @"Suru Verb";         break;
      case WKVocabulary_PartOfSpeech_Prefix:           str = @"Prefix";            break;
      case WKVocabulary_PartOfSpeech_ProperNoun:       str = @"Proper Noun";       break;
      case WKVocabulary_PartOfSpeech_Expression:       str = @"Expression";        break;
      case WKVocabulary_PartOfSpeech_Adjective:        str = @"Adjective";         break;
      case WKVocabulary_PartOfSpeech_Interjection:     str = @"Interjection";      break;
      case WKVocabulary_PartOfSpeech_Counter:          str = @"Counter";           break;
      case WKVocabulary_PartOfSpeech_Pronoun:          str = @"Pronoun";           break;
      case WKVocabulary_PartOfSpeech_Conjunction:      str = @"Conjunction";       break;
    }
    [parts addObject:str];
  }];
  return [parts componentsJoinedByString:@", "];
}

@end

@implementation WKAssignment (Convenience)

- (bool)isReadyForReview {
  if (!self.hasAvailableAt || self.srsStage == 0) {
    return false;
  }
  NSDate *readyForReview = [NSDate dateWithTimeIntervalSince1970:self.availableAt];
  return [readyForReview timeIntervalSinceNow] < 0;
}

@end

@implementation WKProgress (Convenience)

- (NSString *)formParameters {
  return [NSString stringWithFormat:@"%d%%5B%%5D=%@&%d%%5B%%5D=%@",
          self.id_p, self.hasMeaningWrong ? (self.meaningWrong ? @"1" : @"0") : @"",
          self.id_p, self.hasReadingWrong ? (self.readingWrong ? @"1" : @"0") : @""];
}

@end
