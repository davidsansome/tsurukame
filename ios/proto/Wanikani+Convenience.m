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
