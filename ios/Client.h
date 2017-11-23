//
//  Client.h
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#include "proto/Wanikani.pbobjc.h"

#import <Foundation/Foundation.h>

@interface Client : NSObject

- (instancetype)initWithApiToken:(NSString *)apiToken NS_DESIGNATED_INITIALIZER;

typedef void (^AssignmentHandler)(NSArray<WKAssignment *> *);
- (void)getAllAssignments:(AssignmentHandler *)handle;

@end
