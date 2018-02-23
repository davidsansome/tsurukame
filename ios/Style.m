#import "Style.h"

#import <UIKit/UIKit.h>

UIColor *WKVocabularyColor() {
  return [UIColor colorWithRed:0.667f green:0.000f blue:1.000f alpha:1.0f];
}

NSArray<id> *WKRadicalGradient(void) {
  static NSArray<id> *ret;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ret = @[(id)[UIColor colorWithRed:0.000f green:0.667f blue:1.000f alpha:1.0f].CGColor,
            (id)[UIColor colorWithRed:0.000f green:0.576f blue:0.867f alpha:1.0f].CGColor];
  });
  return ret;
}

NSArray<id> *WKKanjiGradient(void) {
  static NSArray<id> *ret;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ret = @[(id)[UIColor colorWithRed:1.000f green:0.000f blue:0.667f alpha:1.0f].CGColor,
            (id)[UIColor colorWithRed:0.867f green:0.000f blue:0.576f alpha:1.0f].CGColor];
  });
  return ret;
}

NSArray<id> *WKVocabularyGradient(void) {
  static NSArray<id> *ret;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ret = @[(id)[UIColor colorWithRed:0.667f green:0.000f blue:1.000f alpha:1.0f].CGColor,
            (id)WKVocabularyColor().CGColor];
  });
  return ret;
}

NSArray<id> *WKGradientForAssignment(WKAssignment *assignment) {
  switch (assignment.subjectType) {
    case WKSubject_Type_Radical:
      return WKRadicalGradient();
    case WKSubject_Type_Kanji:
      return WKKanjiGradient();
    case WKSubject_Type_Vocabulary:
      return WKVocabularyGradient();
  }
}

NSArray<id> *WKGradientForSubject(WKSubject *subject) {
  if (subject.hasRadical) {
    return WKRadicalGradient();
  } else if (subject.hasKanji) {
    return WKKanjiGradient();
  } else if (subject.hasVocabulary) {
    return WKVocabularyGradient();
  }
  return nil;
}
