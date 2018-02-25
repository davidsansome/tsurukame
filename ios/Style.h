#import <UIKit/UIKit.h>

#import "proto/Wanikani.pbobjc.h"

extern UIColor *WKRadicalColor(void);
extern UIColor *WKKanjiColor(void);
extern UIColor *WKVocabularyColor(void);

extern NSArray<id> *WKRadicalGradient(void);
extern NSArray<id> *WKKanjiGradient(void);
extern NSArray<id> *WKVocabularyGradient(void);
extern NSArray<id> *WKGradientForAssignment(WKAssignment *assignment);
extern NSArray<id> *WKGradientForSubject(WKSubject *subject);
