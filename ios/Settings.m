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

#import "Settings.h"
#import "proto/Wanikani.pbobjc.h"

#define DEFINE_OBJECT(type, name, setterName)                                       \
  +(type *)name {                                                                   \
    NSObject *data = [[NSUserDefaults standardUserDefaults] objectForKey:@ #name];  \
    if ([data isKindOfClass:[NSString class]]) {                                    \
      return (type *)data;                                                          \
    } else {                                                                        \
      return (type *)[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)data];    \
    }                                                                               \
  }                                                                                 \
  +(void)setterName : (type *)value {                                               \
    NSData *encodedObject = [NSKeyedArchiver archivedDataWithRootObject:value];     \
    [[NSUserDefaults standardUserDefaults] setObject:encodedObject forKey:@ #name]; \
  }

#define DEFINE_ENUM(type, name, setterName, defaultValue)                    \
  +(type)name {                                                              \
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];              \
    if ([ud integerForKey:@ #name] == 0) {                                   \
      return defaultValue;                                                   \
    }                                                                        \
    return [ud integerForKey:@ #name];                                       \
  }                                                                          \
  +(void)setterName : (type)value {                                          \
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:@ #name]; \
  }

#define DEFINE_BOOL(name, setterName, defaultValue)                       \
  +(BOOL)name {                                                           \
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];           \
    if ([ud objectForKey:@ #name] == nil) {                               \
      return defaultValue;                                                \
    }                                                                     \
    return [ud boolForKey:@ #name];                                       \
  }                                                                       \
  +(void)setterName : (BOOL)value {                                       \
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@ #name]; \
  }

#define DEFINE_INT(name, setterName, defaultValue)                           \
  +(int)name {                                                               \
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];              \
    if ([ud objectForKey:@ #name] == nil) {                                  \
      return defaultValue;                                                   \
    }                                                                        \
    return (int)[ud integerForKey:@ #name];                                  \
  }                                                                          \
  +(void)setterName : (int)value {                                           \
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:@ #name]; \
  }

#define DEFINE_FLOAT(name, setterName, defaultValue)                       \
  +(float)name {                                                           \
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];            \
    if ([ud objectForKey:@ #name] == nil) {                                \
      return defaultValue;                                                 \
    }                                                                      \
    return (float)[ud floatForKey:@ #name];                                \
  }                                                                        \
  +(void)setterName : (float)value {                                       \
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:@ #name]; \
  }

@class TKMFont;

@implementation Settings

+ (void)initializeDefaultsOnStartup {
  // lessonOrder was briefly an array of strings.  Detect this and reset it to
  // an empty array.
  // TODO: delete this after 1.11.
  if (Settings.lessonOrder.count &&
      [Settings.lessonOrder.firstObject isKindOfClass:NSString.class]) {
    Settings.lessonOrder = [NSArray array];
  }

  // Set the default lesson order.
  if (![Settings.lessonOrder count]) {
    NSMutableArray<NSNumber *> *lessonOrder = [NSMutableArray array];
    [lessonOrder addObject:@(TKMSubject_Type_Radical)];
    [lessonOrder addObject:@(TKMSubject_Type_Kanji)];
    [lessonOrder addObject:@(TKMSubject_Type_Vocabulary)];
    Settings.lessonOrder = lessonOrder;
  }
}

DEFINE_OBJECT(NSString, userCookie, setUserCookie);
DEFINE_OBJECT(NSString, userEmailAddress, setUserEmailAddress);
DEFINE_OBJECT(NSString, userApiToken, setUserApiToken);

DEFINE_BOOL(animateParticleExplosion, setAnimateParticleExplosion, YES);
DEFINE_BOOL(animateLevelUpPopup, setAnimateLevelUpPopup, YES);
DEFINE_BOOL(animatePlusOne, setAnimatePlusOne, YES);

DEFINE_BOOL(prioritizeCurrentLevel, setPrioritizeCurrentLevel, NO);
DEFINE_OBJECT(NSArray<NSNumber *>, lessonOrder, setLessonOrder);
DEFINE_INT(lessonBatchSize, setLessonBatchSize, 5);

DEFINE_ENUM(ReviewOrder, reviewOrder, setReviewOrder, ReviewOrder_Random);
DEFINE_INT(reviewBatchSize, setReviewBatchSize, 5);
DEFINE_OBJECT(NSSet<NSString *>, selectedFonts, setSelectedFonts);
DEFINE_BOOL(groupMeaningReading, setGroupMeaningReading, NO);
DEFINE_BOOL(meaningFirst, setMeaningFirst, YES);
DEFINE_BOOL(showAnswerImmediately, setShowAnswerImmediately, YES);
DEFINE_BOOL(allowSkippingReviews, setAllowSkippingReviews, NO);
DEFINE_BOOL(enableCheats, setEnableCheats, YES);
DEFINE_BOOL(showOldMnemonic, setShowOldMnemonic, YES);
DEFINE_BOOL(useKatakanaForOnyomi, setUseKatakanaForOnyomi, NO);
DEFINE_BOOL(showSRSLevelIndicator, setShowSRSLevelIndicator, NO);
DEFINE_BOOL(showAllReadings, setShowAllReadings, NO);
DEFINE_BOOL(autoSwitchKeyboard, setAutoSwitchKeyboard, NO);
DEFINE_ENUM(InterfaceStyle, interfaceStyle, setInterfaceStyle, InterfaceStyle_System);
DEFINE_FLOAT(fontSize, setFontSize, 1.0);

DEFINE_BOOL(playAudioAutomatically, setPlayAudioAutomatically, NO);
DEFINE_OBJECT(NSSet<NSString *>, installedAudioPackages, setInstalledAudioPackages);

DEFINE_BOOL(notificationsAllReviews, setNotificationsAllReviews, NO);
DEFINE_BOOL(notificationsBadging, setNotificationsBadging, YES);

DEFINE_BOOL(subjectCatalogueViewShowAnswers, setSubjectCatalogueViewShowAnswers, YES);
@end
