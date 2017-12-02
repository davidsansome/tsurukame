//
//  ReviewViewController.h
//  Wordlist
//
//  Created by David Sansome on 29/7/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "ReviewItem.h"

@interface ReviewViewController : UIViewController

- (instancetype)initWithItems:(NSArray<ReviewItem *> *)items
                   dataLoader:(DataLoader *)dataLoader NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
