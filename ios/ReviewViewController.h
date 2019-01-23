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

@class ReviewItem;
@class ReviewViewController;
@class TKMServices;

NS_ASSUME_NONNULL_BEGIN;

@protocol ReviewViewControllerDelegate <NSObject>

- (bool)reviewViewControllerAllowsCheatsFor:(ReviewItem *)reviewItem;
- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController;

@optional
- (void)reviewViewController:(ReviewViewController *)reviewViewController
            tappedMenuButton:(UIButton *)menuButton;

@end

@interface ReviewViewController : UIViewController

- (void)setupWithServices:(TKMServices *)services
                    items:(NSArray<ReviewItem *> *)items
           showMenuButton:(BOOL)showMenuButton
       showSubjectHistory:(BOOL)showSubjectHistory
                 delegate:(id<ReviewViewControllerDelegate>)delegate;

@property(nonatomic) bool wrappingUp;
@property(nonatomic, readonly) int tasksAnsweredCorrectly;
@property(nonatomic, readonly) int reviewsCompleted;
@property(nonatomic, readonly) int activeQueueLength;

- (void)focusAnswerField;
- (void)endReviewSession;

@end

NS_ASSUME_NONNULL_END;
