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

extern void WKAddShadowToView(UIView *view, float offset, float opacity, float radius);

extern UIColor *WKKanjiColor1(void);
extern UIColor *WKKanjiColor2(void);
extern UIColor *WKRadicalColor1(void);
extern UIColor *WKRadicalColor2(void);
extern UIColor *WKVocabularyColor1(void);
extern UIColor *WKVocabularyColor2(void);
extern UIColor *WKGreyColor(void);
extern UIColor *WKColor2ForSubjectType(WKSubject_Type subjectType);

extern NSArray<id> *WKRadicalGradient(void);
extern NSArray<id> *WKKanjiGradient(void);
extern NSArray<id> *WKVocabularyGradient(void);
extern NSArray<id> *WKGradientForAssignment(WKAssignment *assignment);
extern NSArray<id> *WKGradientForSubject(WKSubject *subject);

