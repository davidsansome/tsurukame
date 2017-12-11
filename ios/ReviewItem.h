//
//  ReviewItem.h
//  wk
//
//  Created by David Sansome on 28/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "proto/Wanikani.pbobjc.h"

typedef NS_ENUM(NSInteger, WKTaskType) {
  kWKTaskTypeReading,
  kWKTaskTypeMeaning,
  
  kWKTaskType_Max,
};

@interface ReviewItem : NSObject

+ (NSArray<ReviewItem *> *)assignmentsReadyForReview:(NSArray<WKAssignment *> *)assignments;

- (instancetype)initFromAssignment:(WKAssignment *)assignment NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) WKAssignment *assignment;
@property (nonatomic) bool answeredReading;
@property (nonatomic) bool answeredMeaning;
@property (nonatomic) WKProgress *answer;

@end
