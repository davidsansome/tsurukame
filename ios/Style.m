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

#import "Style.h"

#import <UIKit/UIKit.h>

static UIColor *UIColorFromHex(int32_t hexColor) {
  CGFloat red   = (CGFloat)((hexColor & 0xFF0000) >> 16) / 255.f;
  CGFloat green = (CGFloat)((hexColor & 0x00FF00) >> 8)  / 255.f;
  CGFloat blue  = (CGFloat)((hexColor & 0x0000FF))       / 255.f;
  return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
}

static NSArray<id> *ArrayOfTwoColors(UIColor *first, UIColor *second) {
  return @[(id)first.CGColor, (id)second.CGColor];
}

void WKAddShadowToView(UIView *view, float offset, float opacity, float radius) {
  view.layer.shadowColor = [UIColor blackColor].CGColor;
  view.layer.shadowOffset = CGSizeMake(0, offset);
  view.layer.shadowOpacity = opacity;
  view.layer.shadowRadius = radius;
  view.clipsToBounds = NO;
}

UIColor *WKRadicalColor1()    { return UIColorFromHex(0x00AAFF); }
UIColor *WKRadicalColor2()    { return UIColorFromHex(0x0093DD); }
UIColor *WKKanjiColor1()      { return UIColorFromHex(0xFF00AA); }
UIColor *WKKanjiColor2()      { return UIColorFromHex(0xDD0093); }
UIColor *WKVocabularyColor1() { return UIColorFromHex(0xAA00FF); }
UIColor *WKVocabularyColor2() { return UIColorFromHex(0x9300DD); }
UIColor *WKGreyColor()        { return UIColorFromHex(0xC8C8C8); }

UIColor *WKColor2ForSubjectType(WKSubject_Type subjectType) {
  switch (subjectType) {
    case WKSubject_Type_Radical:
      return WKRadicalColor2();
    case WKSubject_Type_Kanji:
      return WKKanjiColor2();
    case WKSubject_Type_Vocabulary:
      return WKVocabularyColor2();
  }
}

NSArray<id> *WKRadicalGradient(void) {
  return ArrayOfTwoColors(WKRadicalColor1(), WKRadicalColor2());
}

NSArray<id> *WKKanjiGradient(void) {
  return ArrayOfTwoColors(WKKanjiColor1(), WKKanjiColor2());
}

NSArray<id> *WKVocabularyGradient(void) {
  return ArrayOfTwoColors(WKVocabularyColor1(), WKVocabularyColor2());
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
