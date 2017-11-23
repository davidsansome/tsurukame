//
//  DataLoader.h
//  wk
//
//  Created by David Sansome on 23/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "proto/Wanikani.pbobjc.h"

@interface DataLoader : NSObject

@property(nonatomic, readonly) NSInteger count;

- (instancetype)initFromURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (WKSubject *)readSubject:(int)subjectID;

@end
