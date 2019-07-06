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
  CGFloat red = (CGFloat)((hexColor & 0xFF0000) >> 16) / 255.f;
  CGFloat green = (CGFloat)((hexColor & 0x00FF00) >> 8) / 255.f;
  CGFloat blue = (CGFloat)((hexColor & 0x0000FF)) / 255.f;
  return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
}

static NSArray<id> *ArrayOfTwoColors(UIColor *first, UIColor *second) {
  return @[ (id)first.CGColor, (id)second.CGColor ];
}

void TKMAddShadowToView(UIView *view, float offset, float opacity, float radius) {
  view.layer.shadowColor = [UIColor blackColor].CGColor;
  view.layer.shadowOffset = CGSizeMake(0, offset);
  view.layer.shadowOpacity = opacity;
  view.layer.shadowRadius = radius;
  view.clipsToBounds = NO;
}

UIColor *TKMDefaultTintColor() {
  return [UIColor colorWithRed:0.0 green:122.0 / 255.0 blue:1.0 alpha:1.0];
}

UIColor *TKMRadicalColor1() { return UIColorFromHex(0x00AAFF); }
UIColor *TKMRadicalColor2() { return UIColorFromHex(0x0093DD); }
UIColor *TKMKanjiColor1() { return UIColorFromHex(0xFF00AA); }
UIColor *TKMKanjiColor2() { return UIColorFromHex(0xDD0093); }
UIColor *TKMVocabularyColor1() { return UIColorFromHex(0xAA00FF); }
UIColor *TKMVocabularyColor2() { return UIColorFromHex(0x9300DD); }
UIColor *TKMLockedColor1() { return UIColorFromHex(0x505050); }
UIColor *TKMLockedColor2() { return UIColorFromHex(0x484848); }
UIColor *TKMGreyColor() { return UIColorFromHex(0xC8C8C8); }

UIColor *TKMColor2ForSubjectType(TKMSubject_Type subjectType) {
  switch (subjectType) {
    case TKMSubject_Type_Radical:
      return TKMRadicalColor2();
    case TKMSubject_Type_Kanji:
      return TKMKanjiColor2();
    case TKMSubject_Type_Vocabulary:
      return TKMVocabularyColor2();
  }
}

NSArray<id> *TKMRadicalGradient(void) {
  return ArrayOfTwoColors(TKMRadicalColor1(), TKMRadicalColor2());
}

NSArray<id> *TKMKanjiGradient(void) { return ArrayOfTwoColors(TKMKanjiColor1(), TKMKanjiColor2()); }

NSArray<id> *TKMVocabularyGradient(void) {
  return ArrayOfTwoColors(TKMVocabularyColor1(), TKMVocabularyColor2());
}

NSArray<id> *TKMLockedGradient(void) {
  return ArrayOfTwoColors(TKMLockedColor1(), TKMLockedColor2());
}

NSArray<id> *TKMGradientForAssignment(TKMAssignment *assignment) {
  switch (assignment.subjectType) {
    case TKMSubject_Type_Radical:
      return TKMRadicalGradient();
    case TKMSubject_Type_Kanji:
      return TKMKanjiGradient();
    case TKMSubject_Type_Vocabulary:
      return TKMVocabularyGradient();
  }
}

NSArray<id> *TKMGradientForSubject(TKMSubject *subject) {
  if (subject.hasRadical) {
    return TKMRadicalGradient();
  } else if (subject.hasKanji) {
    return TKMKanjiGradient();
  } else if (subject.hasVocabulary) {
    return TKMVocabularyGradient();
  }
  return nil;
}

NSString *kTKMJapaneseFontName = @"Hiragino Sans";

UIFont *TKMJapaneseFont(CGFloat size) {
  return [UIFont fontWithName:kTKMJapaneseFontName size:size];
}

UIFont *TKMJapaneseFontLight(CGFloat size) {
  return [UIFont fontWithName:[NSString stringWithFormat:@"%@ W2", kTKMJapaneseFontName] size:size];
}

UIFont *TKMJapaneseFontBold(CGFloat size) {
  return [UIFont fontWithName:[NSString stringWithFormat:@"%@ W7", kTKMJapaneseFontName] size:size];
}
