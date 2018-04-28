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
#import "proto/Wanikani+Convenience.h"

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

WKAnswerCheckerResult CheckAnswer(NSString *answer,
                                  WKSubject *subject,
                                  WKStudyMaterials *studyMaterials,
                                  WKTaskType taskType) {
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
