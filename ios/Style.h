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

extern NSArray<id> *WKRadicalGradient(void);
extern NSArray<id> *WKKanjiGradient(void);
extern NSArray<id> *WKVocabularyGradient(void);
extern NSArray<id> *WKGradientForAssignment(WKAssignment *assignment);
extern NSArray<id> *WKGradientForSubject(WKSubject *subject);

