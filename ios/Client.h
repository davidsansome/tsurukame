//
//  Client.h
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#include "proto/Wanikani.pbobjc.h"

#import <Foundation/Foundation.h>

extern const NSString *WKClientErrorDomain;

@interface Client : NSObject

- (instancetype)initWithApiToken:(NSString *)apiToken NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

typedef void (^AssignmentHandler)(NSError *error, NSArray<WKAssignment *> *);
- (void)getAllAssignments:(AssignmentHandler)handle;

@end
