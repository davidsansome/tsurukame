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
          return kWKAnswerOtherKanjiReading;
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
        int distance = [meaningText levenshteinDistanceTo:answer];
        int tolerance = DistanceTolerance(meaningText);
        NSLog(@"'%@' '%@' distance %d tolerance %d", meaningText, answer, distance, tolerance);
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
