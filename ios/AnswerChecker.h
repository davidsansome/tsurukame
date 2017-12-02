#import <Foundation/Foundation.h>

#import "ReviewItem.h"

typedef NS_ENUM(NSInteger, WKAnswerCheckerResult) {
  kWKAnswerPrecise,
  kWKAnswerImprecise,
  kWKAnswerOtherKanjiReading,
  kWKAnswerContainsInvalidCharacters,
  kWKAnswerIncorrect,
};

extern WKAnswerCheckerResult CheckAnswer(NSString *answer, WKSubject *subject, WKTaskType taskType);
