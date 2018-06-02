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

#import "AnswerChecker.h"
#import "DataLoader.h"
#import "NSString+LevenshteinDistance.h"
#import "proto/Wanikani+Convenience.h"

static const char *kKanaCharacters =
    "あいうえお"
    "かきくけこがぎぐげご"
    "さしすせそざじずぜぞ"
    "たちつてとだぢづでど"
    "なにぬねの"
    "はひふへほばびぶべぼぱぴぷぺぽ"
    "まみむめも"
    "らりるれろ"
    "やゆよゃゅょぃっ"
    "わをん"
    "アイウエオ"
    "カキクケコガギグゲゴ"
    "サシスセソザジズゼゾ"
    "タチツテトダヂヅデド"
    "ナニヌネノ"
    "ハヒフヘホバビブベボパピプペポ"
    "マミムメモ"
    "ラリルレロ"
    "ヤユトャュョィッ"
    "ワヲン";


static NSString *FormattedString(NSString *s) {
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  s = [s lowercaseString];
  s = [s stringByReplacingOccurrencesOfString:@"-" withString:@" "];
  s = [s stringByReplacingOccurrencesOfString:@"." withString:@""];
  s = [s stringByReplacingOccurrencesOfString:@"'" withString:@""];
  s = [s stringByReplacingOccurrencesOfString:@"/" withString:@""];
  return s;
}

static BOOL IsAsciiPresent(NSString *s) {
  static NSCharacterSet *kAsciiCharacterSet;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kAsciiCharacterSet = [NSCharacterSet characterSetWithRange:NSMakeRange(0, 255)];
  });
  
  return [s rangeOfCharacterFromSet:kAsciiCharacterSet].location != NSNotFound;
}

static int DistanceTolerance(NSString *answer) {
  if (answer.length <= 3) {
    return 0;
  }
  if (answer.length <= 5) {
    return 1;
  }
  if (answer.length <= 7) {
    return 2;
  }
  return 2 + 1 * floor((double)(answer.length) / 7);
}

static BOOL MismatchingOkurigana(NSString *answer, NSString *japanese) {
  static dispatch_once_t onceToken;
  static NSCharacterSet *kKanaCharacterSet;
  dispatch_once(&onceToken, ^{
    kKanaCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@(kKanaCharacters)];
  });
  
  if (answer.length < japanese.length) {
    return NO;
  }
  
  for (int i = 0; i < japanese.length; ++i) {
    unichar japaneseChar = [japanese characterAtIndex:i];
    if (![kKanaCharacterSet characterIsMember:japaneseChar]) {
      break;
    }
    unichar answerChar = [answer characterAtIndex:i];
    if (japaneseChar != answerChar) {
      return YES;
    }
  }
  
  for (int i = 0; i < japanese.length; ++i) {
    unichar japaneseChar = [japanese characterAtIndex:japanese.length - i];
    if (![kKanaCharacterSet characterIsMember:japaneseChar]) {
      break;
    }
    unichar answerChar = [answer characterAtIndex:answer.length - i];
    if (japaneseChar != answerChar) {
      return YES;
    }
  }
  
  return NO;
}

WKAnswerCheckerResult CheckAnswer(NSString *answer,
                                  WKSubject *subject,
                                  WKStudyMaterials *studyMaterials,
                                  WKTaskType taskType,
                                  DataLoader *dataLoader) {
  answer = FormattedString(answer);
  
  switch (taskType) {
    case kWKTaskTypeReading:
      answer = [answer stringByReplacingOccurrencesOfString:@"n" withString:@"ん"];
      if (IsAsciiPresent(answer)) {
        return kWKAnswerContainsInvalidCharacters;
      }
      
      for (WKReading *reading in subject.primaryReadings) {
        if ([reading.reading isEqualToString:answer]) {
          return kWKAnswerPrecise;
        }
      }
      for (WKReading *reading in subject.alternateReadings) {
        if ([reading.reading isEqualToString:answer]) {
          return subject.hasKanji ? kWKAnswerOtherKanjiReading : kWKAnswerPrecise;
        }
      }
      if (subject.hasVocabulary && subject.japanese.length == 1 &&
          subject.componentSubjectIdsArray_Count == 1) {
        // If the vocabulary is made up of only one Kanji, check whether the user wrote the Kanji
        // reading instead of the vocabulary reading.
        WKSubject *kanji = [dataLoader loadSubject:[subject.componentSubjectIdsArray valueAtIndex:0]];
        WKAnswerCheckerResult kanjiResult = CheckAnswer(answer, kanji, nil, taskType, dataLoader);
        if (kanjiResult == kWKAnswerPrecise) {
          return kWKAnswerOtherKanjiReading;
        }
      }
      if (subject.hasVocabulary && MismatchingOkurigana(answer, subject.japanese)) {
        return kWKAnswerOtherKanjiReading;
      }
      break;
      
    case kWKTaskTypeMeaning: {
      NSMutableArray<NSString *> *meaningTexts =
          [NSMutableArray arrayWithArray:studyMaterials.meaningSynonymsArray];
      
      for (WKMeaning *meaning in subject.meaningsArray) {
        [meaningTexts addObject:meaning.meaning];
      }
      
      for (NSString *meaning in meaningTexts) {
        NSString *meaningText = FormattedString(meaning);
        if ([meaningText isEqualToString:answer]) {
          return kWKAnswerPrecise;
        }
      }
      for (NSString *meaning in meaningTexts) {
        NSString *meaningText = FormattedString(meaning);
        int distance = [meaningText levenshteinDistanceTo:answer];
        int tolerance = DistanceTolerance(meaningText);
        if (distance <= tolerance) {
          return kWKAnswerImprecise;
        }
      }
      break;
    }
      
    case kWKTaskType_Max:
      assert(false);
  }
  return kWKAnswerIncorrect;
}
