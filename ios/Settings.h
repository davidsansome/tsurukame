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

#import "TKMFontLoader.h"

#import <Foundation/Foundation.h>
#import <Protobuf-umbrella.h>

#define DECLARE_OBJECT(type, name) @property(class, nonatomic, copy) type *name;

#define DECLARE_ENUM(type, name) @property(class, nonatomic) type name;

#define DECLARE_BOOL(name) @property(class, nonatomic) BOOL name;

#define DECLARE_INT(name) @property(class, nonatomic) int name;

#define DECLARE_FLOAT(name) @property(class, nonatomic) float name;

typedef NS_ENUM(NSUInteger, ReviewOrder) {
  ReviewOrder_Random = 1,
  ReviewOrder_AscendingSRSStage = 2,
  ReviewOrder_CurrentLevelFirst = 3,
  ReviewOrder_LowestLevelFirst = 4,
  ReviewOrder_NewestAvailableFirst = 5,
  ReviewOrder_OldestAvailableFirst = 6,
  ReviewOrder_DescendingSRSStage = 7,
};

typedef NS_CLOSED_ENUM(NSUInteger, InterfaceStyle){
    InterfaceStyle_System = 1, InterfaceStyle_Light = 2, InterfaceStyle_Dark = 3};

@interface Settings : NSObject

+ (void)initializeDefaultsOnStartup;

// User credentials.
DECLARE_OBJECT(NSString, userCookie);
DECLARE_OBJECT(NSString, userEmailAddress);
DECLARE_OBJECT(NSString, userApiToken);

// Animation settings.
DECLARE_BOOL(animateParticleExplosion);
DECLARE_BOOL(animateLevelUpPopup);
DECLARE_BOOL(animatePlusOne);

// Lesson settings.
DECLARE_BOOL(prioritizeCurrentLevel);
DECLARE_OBJECT(NSArray<NSNumber *>, lessonOrder);
DECLARE_INT(lessonBatchSize);

// Review settings.
DECLARE_ENUM(ReviewOrder, reviewOrder);
DECLARE_INT(reviewBatchSize);
DECLARE_OBJECT(NSSet<NSString *>, selectedFonts);
DECLARE_BOOL(groupMeaningReading);
DECLARE_BOOL(meaningFirst);
DECLARE_BOOL(showAnswerImmediately);
DECLARE_BOOL(allowSkippingReviews);
DECLARE_BOOL(enableCheats);
DECLARE_BOOL(showOldMnemonic);
DECLARE_BOOL(useKatakanaForOnyomi);
DECLARE_BOOL(showSRSLevelIndicator);
DECLARE_BOOL(showAllReadings);
DECLARE_BOOL(autoSwitchKeyboard);
DECLARE_ENUM(InterfaceStyle, interfaceStyle);
DECLARE_FLOAT(fontSize);

// Offline audio.
DECLARE_BOOL(playAudioAutomatically);
DECLARE_OBJECT(NSSet<NSString *>, installedAudioPackages);

// Notifications.
DECLARE_BOOL(notificationsAllReviews);
DECLARE_BOOL(notificationsBadging);

// Subject Catalogue View internal settings.
DECLARE_BOOL(subjectCatalogueViewShowAnswers)

@end
