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

#import <UIKit/UIKit.h>

#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

extern void TKMAddShadowToView(UIView *view, float offset, float opacity, float radius);

extern UIColor *TKMDefaultTintColor(void);

extern UIColor *TKMKanjiColor1(void);
extern UIColor *TKMKanjiColor2(void);
extern UIColor *TKMRadicalColor1(void);
extern UIColor *TKMRadicalColor2(void);
extern UIColor *TKMVocabularyColor1(void);
extern UIColor *TKMVocabularyColor2(void);
extern UIColor *TKMGreyColor(void);
extern UIColor *TKMColor2ForSubjectType(TKMSubject_Type subjectType);

extern NSArray<id> *TKMRadicalGradient(void);
extern NSArray<id> *TKMKanjiGradient(void);
extern NSArray<id> *TKMVocabularyGradient(void);
extern NSArray<id> *TKMLockedGradient(void);
extern NSArray<id> *TKMGradientForAssignment(TKMAssignment *assignment);
extern NSArray<id> *TKMGradientForSubject(TKMSubject *subject);

// Fonts that render Chinese characters in Japanese glyphs.  This is useful because iOS chooses
// a Chinese font to render these characters if the user hasn't selected Japanese as a secondary
// system font.
extern NSString *kTKMJapaneseFontName;
extern UIFont *TKMJapaneseFont(CGFloat size);
extern UIFont *TKMJapaneseFontLight(CGFloat size);
extern UIFont *TKMJapaneseFontBold(CGFloat size);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
