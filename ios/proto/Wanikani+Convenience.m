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

@end
