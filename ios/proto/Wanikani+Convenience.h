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

#import <CoreGraphics/CoreGraphics.h>

#import "Wanikani.pbobjc.h"

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *TKMSubjectTypeName(TKMSubject_Type subjectType);
extern NSString *TKMSRSStageName(int srsStage);
extern NSString *TKMDetailedSRSStageName(int srsStage);

/**
 * Returns the minimum time it would take to get an item at the given level and SRS stage up to the
 * Guru level.
 */
NSTimeInterval TKMMinimumTimeUntilGuruSeconds(int itemLevel, int srsStage);

typedef NS_ENUM(NSInteger, TKMSRSStageCategory) {
  TKMSRSStageNovice = 0,
  TKMSRSStageApprentice = 1,
  TKMSRSStageGuru = 2,
  TKMSRSStageMaster = 3,
  TKMSRSStageEnlightened = 4,
  TKMSRSStageBurned = 5,
};
extern TKMSRSStageCategory TKMSRSStageCategoryForStage(int srsStage);
extern int TKMFirstSRSStageInCategory(TKMSRSStageCategory category);
extern NSString *TKMSRSStageCategoryName(TKMSRSStageCategory category);

#ifdef __cplusplus
}
#endif

@interface TKMSubject (Convenience)

@property(nonatomic, readonly) TKMSubject_Type subjectType;
@property(nonatomic, readonly) NSString *subjectTypeString;
@property(nonatomic, readonly) NSString *primaryMeaning;
@property(nonatomic, readonly) NSArray<TKMReading *> *primaryReadings;
@property(nonatomic, readonly) NSArray<TKMReading *> *alternateReadings;
@property(nonatomic, readonly) NSString *commaSeparatedReadings;
@property(nonatomic, readonly) NSString *commaSeparatedPrimaryReadings;
@property(nonatomic, readonly) NSString *commaSeparatedMeanings;
@property(nonatomic, readonly) NSAttributedString *japaneseText;

- (NSAttributedString *)japaneseTextWithImageSize:(CGFloat)imageSize;
- (int)randomAudioID;

@end

@interface TKMReading (Convenience)

@property(nonatomic, readonly) NSString *displayText;

@end

@interface TKMVocabulary (Convenience)

@property(nonatomic, readonly) NSString *commaSeparatedPartsOfSpeech;
@property(nonatomic, readonly) bool isNoun;
@property(nonatomic, readonly) bool isVerb;
@property(nonatomic, readonly) bool isGodanVerb;
@property(nonatomic, readonly) bool isSuruVerb;
@property(nonatomic, readonly) bool isAdjective;
@property(nonatomic, readonly) bool isPrefixOrSuffix;

@end

@interface TKMAssignment (Convenience)

@property(nonatomic, readonly) bool isLessonStage;
@property(nonatomic, readonly) bool isReviewStage;
@property(nonatomic, readonly) bool isBurned;
@property(nonatomic, readonly) bool isLocked;
@property(nonatomic, readonly) NSDate *availableAtDate;
@property(nonatomic, readonly) NSDate *startedAtDate;
@property(nonatomic, readonly) NSDate *passedAtDate;

/**
 * The date the assignment can be reviewed (or now, if it's already available), rounded to the
 * nearest hour. nil if the item is burned or locked.
 */
@property(nonatomic, nullable, readonly) NSDate *reviewDate;

/** The earliest date possible to get this item to Guru level. */
- (NSDate *)guruDateForSubject:(TKMSubject *)subject;

@end

@interface TKMProgress (Convenience)

@property(nonatomic, readonly) NSString *reviewFormParameters;
@property(nonatomic, readonly) NSString *lessonFormParameters;
@property(nonatomic, readonly) NSDate *createdAtDate;

@end

@interface TKMUser (Convenience)

@property(nonatomic, readonly) NSDate *startedAtDate;
- (int)currentLevel;

@end

@interface TKMLevel (Convenience)

- (NSTimeInterval)timeSpentCurrent;

@end

NS_ASSUME_NONNULL_END
