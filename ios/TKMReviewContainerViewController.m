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

#import "TKMReviewContainerViewController.h"

#import "TKMReviewMenuViewController.h"
#import "Tsurukame-Swift.h"

#import <MMDrawerController/MMDrawerVisualState.h>

@interface MMDrawerController (Secret)

- (void)setAnimatingDrawer:(BOOL)animatingDrawer;

@end

@interface TKMReviewContainerViewController () <ReviewViewControllerDelegate, TKMReviewMenuDelegate>

@end

@implementation TKMReviewContainerViewController {
  TKMServices *_services;
  ReviewViewController *_reviewVC;
}

- (void)setupWithServices:(TKMServices *)services items:(NSArray *)items {
  _reviewVC = [self.storyboard instantiateViewControllerWithIdentifier:@"reviewViewController"];
  [_reviewVC setupWithServices:services
                         items:items
                showMenuButton:YES
            showSubjectHistory:YES
                      delegate:self];

  TKMReviewMenuViewController *menuVC =
      [self.storyboard instantiateViewControllerWithIdentifier:@"reviewMenuViewController"];
  menuVC.delegate = self;

  [self setCenterViewController:_reviewVC];
  [self setLeftDrawerViewController:menuVC];
  self.shouldStretchDrawer = NO;
  self.closeDrawerGestureModeMask = MMCloseDrawerGestureModeAll;
  self.centerHiddenInteractionMode = MMDrawerOpenCenterInteractionModeNone;
  [self setDrawerVisualStateBlock:[MMDrawerVisualState
                                      parallaxVisualStateBlockWithParallaxFactor:1.f]];
}

- (void)setAnimatingDrawer:(BOOL)animatingDrawer {
  [super setAnimatingDrawer:animatingDrawer];

  // Hide the keyboard if we're opening the drawer, show it if we're closing it.
  if ((animatingDrawer && self.openSide == MMDrawerSideNone) ||
      (!animatingDrawer && self.openSide != MMDrawerSideNone)) {
    [self.view endEditing:YES];
  } else if (animatingDrawer && self.openSide != MMDrawerSideNone) {
    [_reviewVC focusAnswerField];
  }
}

#pragma mark - ReviewViewControllerDelegate

- (BOOL)reviewViewControllerAllowsCheatsForReviewItem:(ReviewItem *)reviewItem {
  return Settings.enableCheats;
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
            tappedMenuButton:(UIButton *)menuButton {
  [self openDrawerSide:MMDrawerSideLeft animated:YES completion:nil];
}

- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController {
  [reviewViewController performSegueWithIdentifier:@"reviewSummary" sender:reviewViewController];
}

- (BOOL)reviewViewControllerAllowsCustomFonts {
  return true;
}

- (BOOL)reviewViewControllerShowsSuccessRate {
  return true;
}

#pragma mark - TKMReviewMenuDelegate

- (void)didTapEndReviewSession:(UIView *)button {
  if (_reviewVC.tasksAnsweredCorrectly == 0) {
    [self.navigationController popToRootViewControllerAnimated:YES];
    return;
  }

  UIAlertController *c = [UIAlertController
      alertControllerWithTitle:@"End review session?"
                       message:@"You'll lose progress on any half-answered reviews"
                preferredStyle:UIAlertControllerStyleActionSheet];
  c.popoverPresentationController.sourceView = button;
  c.popoverPresentationController.sourceRect = button.bounds;

  [c addAction:[UIAlertAction actionWithTitle:@"End review session"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        [_reviewVC endReviewSession];
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)didTapWrapUp {
  _reviewVC.wrappingUp = !_reviewVC.wrappingUp;
  [self closeDrawerAnimated:YES completion:nil];
}

- (int)wrapUpCount {
  if (_reviewVC.wrappingUp) {
    return (int)_reviewVC.activeQueueLength;
  }
  return 0;
}

@end
