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

#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "ReviewItem.h"

@class ReviewViewController;

@protocol ReviewViewControllerDelegate <NSObject>

- (bool)reviewViewController:(ReviewViewController *)reviewViewController
             allowsCheatsFor:(ReviewItem *)reviewItem;

- (void)reviewViewController:(ReviewViewController *)reviewViewController
            tappedBackButton:(UIButton *)backButton;
- (void)reviewViewController:(ReviewViewController *)reviewViewController
          finishedReviewItem:(ReviewItem *)reviewItem;
- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController;

@end


@interface ReviewViewController : UIViewController

// Must set these prior to starting.
@property(nonatomic, assign) DataLoader *dataLoader;
@property(nonatomic, assign) LocalCachingClient *localCachingClient;
@property(nonatomic, copy) NSArray<ReviewItem *> *items;
@property(nonatomic) bool hideBackButton;

@property(nonatomic, weak) id<ReviewViewControllerDelegate> delegate;

@property(nonatomic) bool wrappingUp;
@property(nonatomic, readonly) int reviewsCompleted;

@end


@interface DefaultReviewViewControllerDelegate : NSObject<ReviewViewControllerDelegate>
@end
