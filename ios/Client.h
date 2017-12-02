//
//  Client.h
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#include "proto/Wanikani.pbobjc.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain WKClientErrorDomain;

@interface Client : NSObject

- (instancetype)initWithApiToken:(NSString *)apiToken NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

typedef void (^AssignmentHandler)(NSError * _Nullable error,
                                  NSArray<WKAssignment *> * _Nullable assignments);
- (void)getAllAssignments:(AssignmentHandler)handle;

@end

NS_ASSUME_NONNULL_END
