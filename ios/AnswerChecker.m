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
#import "NSString+LevenshteinDistance.h"
#import "Tsurukame-Swift.h"
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
    "わをん";

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

NSCharacterSet *TKMKanaCharacterSet() {
  static dispatch_once_t onceToken;
  static NSCharacterSet *kKanaCharacterSet;
  dispatch_once(&onceToken, ^{
    kKanaCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@(kKanaCharacters)];
  });
  return kKanaCharacterSet;
}

static BOOL MismatchingOkurigana(NSString *answer, NSString *japanese) {
  NSCharacterSet *kanaCharacterSet = TKMKanaCharacterSet();

  if (answer.length < japanese.length) {
    return NO;
  }

  for (int i = 0; i < japanese.length; ++i) {
    unichar japaneseChar = [japanese characterAtIndex:i];
    if (![kanaCharacterSet characterIsMember:japaneseChar]) {
      break;
    }
    unichar answerChar = [answer characterAtIndex:i];
    if (japaneseChar != answerChar) {
      return YES;
    }
  }

  for (int i = 1; i <= japanese.length; ++i) {
    unichar japaneseChar = [japanese characterAtIndex:japanese.length - i];
    if (![kanaCharacterSet characterIsMember:japaneseChar]) {
      break;
    }
    unichar answerChar = [answer characterAtIndex:answer.length - i];
    if (japaneseChar != answerChar) {
      return YES;
    }
  }

  return NO;
}

NSString *ConvertHiraganaToKatakana(NSString *text) {
  // NSStringTransformHiraganaToKatakana munges long-dashes so we need to special case strings that
  // contain those.
  NSRange dash = [text rangeOfString:@"ー"];
  if (dash.location == NSNotFound) {
    return [text stringByApplyingTransform:NSStringTransformHiraganaToKatakana reverse:YES];
  }

  NSMutableString *ret = [NSMutableString string];
  [ret appendString:ConvertHiraganaToKatakana([text substringToIndex:dash.location])];
  [ret appendString:@"ー"];
  [ret appendString:ConvertHiraganaToKatakana([text substringFromIndex:dash.location + 1])];
  return ret;
}

TKMAnswerCheckerResult CheckAnswer(NSString **answer,
                                   TKMSubject *subject,
                                   TKMStudyMaterials *studyMaterials,
                                   TKMTaskType taskType,
                                   DataLoader *dataLoader) {
  *answer = FormattedString(*answer);

  switch (taskType) {
    case kTKMTaskTypeReading: {
      *answer = [*answer stringByReplacingOccurrencesOfString:@"n" withString:@"ん"];
      *answer = [*answer stringByReplacingOccurrencesOfString:@" " withString:@""];
      NSString *hiraganaAnswer = ConvertHiraganaToKatakana(*answer);

      if (IsAsciiPresent(*answer)) {
        return kTKMAnswerContainsInvalidCharacters;
      }

      for (TKMReading *reading in subject.primaryReadings) {
        if ([reading.reading isEqualToString:hiraganaAnswer]) {
          return kTKMAnswerPrecise;
        }
      }
      for (TKMReading *reading in subject.alternateReadings) {
        if ([reading.reading isEqualToString:hiraganaAnswer]) {
          return subject.hasKanji ? kTKMAnswerOtherKanjiReading : kTKMAnswerPrecise;
        }
      }
      if (subject.hasVocabulary && subject.japanese.length == 1 &&
          subject.componentSubjectIdsArray_Count == 1) {
        // If the vocabulary is made up of only one Kanji, check whether the user wrote the Kanji
        // reading instead of the vocabulary reading.
        TKMSubject *kanji =
            [dataLoader loadSubject:[subject.componentSubjectIdsArray valueAtIndex:0]];
        TKMAnswerCheckerResult kanjiResult = CheckAnswer(answer, kanji, nil, taskType, dataLoader);
        if (kanjiResult == kTKMAnswerPrecise) {
          return kTKMAnswerOtherKanjiReading;
        }
      }
      if (subject.hasVocabulary && MismatchingOkurigana(*answer, subject.japanese)) {
        return kTKMAnswerOtherKanjiReading;
      }
      break;
    }

    case kTKMTaskTypeMeaning: {
      NSMutableArray<NSString *> *meaningTexts =
          [NSMutableArray arrayWithArray:studyMaterials.meaningSynonymsArray];

      for (TKMMeaning *meaning in subject.meaningsArray) {
        if (meaning.type != TKMMeaning_Type_Blacklist) {
          [meaningTexts addObject:meaning.meaning];
        }
      }

      for (NSString *meaning in meaningTexts) {
        NSString *meaningText = FormattedString(meaning);
        if ([meaningText isEqualToString:*answer]) {
          return kTKMAnswerPrecise;
        }
      }
      for (NSString *meaning in meaningTexts) {
        NSString *meaningText = FormattedString(meaning);
        int distance = [meaningText levenshteinDistanceTo:*answer];
        int tolerance = DistanceTolerance(meaningText);
        if (distance <= tolerance) {
          return kTKMAnswerImprecise;
        }
      }
      break;
    }

    case kTKMTaskType_Max:
      assert(false);
  }
  return kTKMAnswerIncorrect;
}
