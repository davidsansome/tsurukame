#import <Foundation/Foundation.h>

#import "proto/Wanikani.pbobjc.h"

extern NSArray<id> *WKRadicalGradient(void);
extern NSArray<id> *WKKanjiGradient(void);
extern NSArray<id> *WKVocabularyGradient(void);
extern NSArray<id> *WKGradientForAssignment(WKAssignment *assignment);
extern NSArray<id> *WKGradientForSubject(WKSubject *subject);
