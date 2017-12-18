//
//  Wanikani+Convenience.m
//  wk
//
//  Created by David Sansome on 28/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "Wanikani+Convenience.h"

static NSString *CommaSeparatedReadings(NSArray<WKReading *>* readings) {
  NSMutableArray<NSString *>* strings = [NSMutableArray array];
  for (WKReading *reading in readings) {
    [strings addObject:reading.reading];
  }
  return [strings componentsJoinedByString:@", "];
}

static NSString *CommaSeparatedMeanings(NSArray<WKMeaning *>* meanings) {
  NSMutableArray<NSString *>* strings = [NSMutableArray array];
  for (WKMeaning *meaning in meanings) {
    [strings addObject:meaning.meaning];
  }
  return [strings componentsJoinedByString:@", "];
}

@implementation WKSubject (Convenience)

- (NSString *)primaryMeaning {
  if (self.hasVocabulary) {
    return [self primaryMeaningFrom:self.vocabulary.meaningsArray];
  } else if (self.hasKanji) {
    return [self primaryMeaningFrom:self.kanji.meaningsArray];
  } else if (self.hasRadical) {
    return [self primaryMeaningFrom:self.radical.meaningsArray];
  }
  return nil;
}

- (NSString *)primaryMeaningFrom:(NSArray<WKMeaning *> *)meanings {
  for (WKMeaning *meaning in meanings) {
    if (meaning.isPrimary) {
      return meaning.meaning;
    }
  }
  return nil;
}

- (NSArray<WKReading *> *)primaryReadings {
  if (self.hasVocabulary) {
    return [self readingsFrom:self.vocabulary.readingsArray primary:YES];
  } else if (self.hasKanji) {
    return [self readingsFrom:self.kanji.readingsArray primary:YES];
  }
  return nil;
}

- (NSArray<WKReading *> *)alternateReadings {
  if (self.hasVocabulary) {
    return [self readingsFrom:self.vocabulary.readingsArray primary:NO];
  } else if (self.hasKanji) {
    return [self readingsFrom:self.kanji.readingsArray primary:NO];
  }
  return nil;
}

- (NSArray<WKReading *> *)readingsFrom:(NSArray<WKReading *> *)readings primary:(BOOL)primary {
  NSMutableArray<WKReading *> *ret = [NSMutableArray array];
  for (WKReading *reading in readings) {
    if (reading.isPrimary == primary) {
      [ret addObject:reading];
    }
  }
  return ret;
}

- (NSString *)japanese {
  if (self.hasVocabulary) {
    return self.vocabulary.japanese;
  } else if (self.hasKanji) {
    return self.kanji.japanese;
  } else if (self.hasRadical) {
    return self.radical.japanese;
  }
  return nil;
}

- (NSArray<WKMeaning *> *)meanings {
  if (self.hasVocabulary) {
    return self.vocabulary.meaningsArray;
  } else if (self.hasKanji) {
    return self.kanji.meaningsArray;
  } else if (self.hasRadical) {
    return self.radical.meaningsArray;
  }
  return nil;
}

@end

@implementation WKRadical (Convenience)

- (NSString *)commaSeparatedMeanings {
  return CommaSeparatedMeanings(self.meaningsArray);
}

@end

@implementation WKKanji (Convenience)

- (NSString *)commaSeparatedMeanings {
  return CommaSeparatedMeanings(self.meaningsArray);
}

- (NSString *)commaSeparatedReadings {
  return CommaSeparatedReadings(self.readingsArray);
}

@end

@implementation WKVocabulary (Convenience)

- (NSString *)commaSeparatedMeanings {
  return CommaSeparatedMeanings(self.meaningsArray);
}

- (NSString *)commaSeparatedReadings {
  return CommaSeparatedReadings(self.readingsArray);
}

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
  if (!self.hasAvailableAt || !self.hasStartedAt) {
    return false;
  }
  NSDate *readyForReview = [NSDate dateWithTimeIntervalSince1970:self.availableAt];
  return [readyForReview timeIntervalSinceNow] < 0;
}

@end
