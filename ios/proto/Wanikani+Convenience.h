#import <CoreGraphics/CoreGraphics.h>

#import "Wanikani.pbobjc.h"

@interface WKSubject (Convenience)

@property (nonatomic, readonly) NSString *subjectType;
@property (nonatomic, readonly) NSString *primaryMeaning;
@property (nonatomic, readonly) NSArray<WKReading *> *primaryReadings;
@property (nonatomic, readonly) NSArray<WKReading *> *alternateReadings;
@property (nonatomic, readonly) NSString *commaSeparatedReadings;
@property (nonatomic, readonly) NSString *commaSeparatedMeanings;
@property (nonatomic, readonly) NSAttributedString *japaneseText;

- (NSAttributedString *)japaneseTextWithImageSize:(CGFloat)imageSize;

@end

@interface WKVocabulary (Convenience)

@property (nonatomic, readonly) NSString *commaSeparatedPartsOfSpeech;

@end

@interface WKAssignment (Convenience)

@property (nonatomic, readonly) bool isReadyForReview;
@property (nonatomic, readonly) bool isReadyForLesson;

@end

@interface WKProgress (Convenience)

@property (nonatomic, readonly) NSString *reviewFormParameters;
@property (nonatomic, readonly) NSString *lessonFormParameters;

@end

@interface WKUser (Convenience)

@property (nonatomic, readonly) NSDate *startedAtDate;

@end
