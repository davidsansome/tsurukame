//
//  Tsurukame
//
//  Created by André Arko on 7/14/19.
//  Copyright © 2019 David Sansome. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "proto/Wanikani+Convenience.h"
#import "TKMSubjectDelegate.h"

@class TKMServices;

NS_ASSUME_NONNULL_BEGIN

@interface LevelTimeRemainingCell : UITableViewCell <TKMSubjectDelegate>

- (void)setupWithServices:(TKMServices *)services;
- (void)update:(NSArray<TKMAssignment *> *)assignments;

@end

NS_ASSUME_NONNULL_END
