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

@interface WKSubject (Convenience)

@property (nonatomic, readonly) NSString *subjectType;
@property (nonatomic, readonly) NSString *primaryMeaning;
@property (nonatomic, readonly) NSArray<WKReading *> *primaryReadings;
@property (nonatomic, readonly) NSArray<WKReading *> *alternateReadings;
@property (nonatomic, readonly) NSString *commaSeparatedReadings;
@property (nonatomic, readonly) NSString *commaSeparatedPrimaryReadings;
@property (nonatomic, readonly) NSString *commaSeparatedMeanings;
@property (nonatomic, readonly) NSAttributedString *japaneseText;

- (NSAttributedString *)japaneseTextWithImageSize:(CGFloat)imageSize;

@end

@interface WKVocabulary (Convenience)

@property (nonatomic, readonly) NSString *commaSeparatedPartsOfSpeech;

@end

@interface WKAssignment (Convenience)

@property (nonatomic, readonly) bool isLessonStage;
@property (nonatomic, readonly) bool isReviewStage;
@property (nonatomic, readonly) NSDate *availableAtDate;

@end

@interface WKProgress (Convenience)

@property (nonatomic, readonly) NSString *reviewFormParameters;
@property (nonatomic, readonly) NSString *lessonFormParameters;

@end

@interface WKUser (Convenience)

@property (nonatomic, readonly) NSDate *startedAtDate;

@end
