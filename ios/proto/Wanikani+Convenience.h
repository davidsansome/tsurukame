//
//  Wanikani+Convenience.h
//  wk
//
//  Created by David Sansome on 28/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Wanikani.pbobjc.h"

@interface WKSubject (Convenience)

@property (nonatomic, readonly) NSString *subjectType;
@property (nonatomic, readonly) NSString *primaryMeaning;
@property (nonatomic, readonly) NSArray<WKReading *> *primaryReadings;
@property (nonatomic, readonly) NSArray<WKReading *> *alternateReadings;
@property (nonatomic, readonly) NSString *commaSeparatedReadings;
@property (nonatomic, readonly) NSString *commaSeparatedMeanings;
@property (nonatomic, readonly) NSAttributedString *japaneseText;

@end

@interface WKVocabulary (Convenience)

@property (nonatomic, readonly) NSString *commaSeparatedPartsOfSpeech;

@end

@interface WKAssignment (Convenience)

@property (nonatomic, readonly) bool isReadyForReview;
@property (nonatomic, readonly) bool isReadyForLesson;

@end

@interface WKProgress (Convenience)

@property (nonatomic, readonly) NSString *formParameters;

@end
