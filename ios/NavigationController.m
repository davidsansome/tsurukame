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

#import "NavigationController.h"

#import <objc/runtime.h>

@interface UINavigationController ()
- (BOOL)_shouldCrossFadeNavigationBar;
@end

#pragma mark - NavigationController

@interface NavigationController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate>
@end

@implementation NavigationController {
  bool _isPushingViewController;

  // A pan gesture recogniser that makes it possible to swipe back from anywhere on the view.
  UIPanGestureRecognizer *_panGestureRecognizer;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.delegate = self;
  self.interactivePopGestureRecognizer.delegate = self;

  // Add a new pan gesture recogniser, but copy the targets list from the built-in edge pop
  // recogniser.
  NSMutableArray *targets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
  _panGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
  [_panGestureRecognizer setValue:targets forKey:@"targets"];
  [_panGestureRecognizer setDelegate:self];
  [self.view addGestureRecognizer:_panGestureRecognizer];
}

#pragma mark - UIViewController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
  _isPushingViewController = true;
  [super pushViewController:viewController animated:animated];
}

- (BOOL)_shouldCrossFadeBottomBars {
  return NO;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  if (gestureRecognizer == self.interactivePopGestureRecognizer ||
      gestureRecognizer == _panGestureRecognizer) {
    if (self.viewControllers.count <= 1 || _isPushingViewController) {
      return NO;
    }

    if (gestureRecognizer == _panGestureRecognizer) {
      CGPoint velocity = [_panGestureRecognizer velocityInView:self.topViewController.view];
      if (velocity.x < 0 || fabs(velocity.y) > fabs(velocity.x)) {
        return NO;
      }
    }

    id<TKMViewController> topViewController = (id<TKMViewController>)self.topViewController;
    if ([topViewController respondsToSelector:@selector(canSwipeToGoBack)]) {
      return [topViewController canSwipeToGoBack];
    }
    return NO;
  }
  return YES;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
  _isPushingViewController = false;
}

@end
