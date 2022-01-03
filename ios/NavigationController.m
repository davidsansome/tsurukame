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

// Speed (in points/sec) the user has to fling the view to finish the animation.
static const CGFloat kVelocityThreshold = 60.f;

#pragma mark - UIPanGestureRecognizer hackery

// Expose the internals of this private UIKit class.
@interface UIGestureRecognizerTarget : NSObject
@property(nonatomic, readonly) SEL action;
@property(nonatomic, readonly) id target;
@end

@interface UINavigationController ()
- (BOOL)_shouldCrossFadeNavigationBar;
@end

// An object that looks enough like a UIPanGestureRecognizer to pass to UINavigationController's
// builtin transition handler.
@interface FakeGestureRecognizer : UIPanGestureRecognizer
@end

@implementation FakeGestureRecognizer {
  UIPanGestureRecognizer *_delegate;
  CGFloat _horizontalTranslation;
}

- (instancetype)initWithDelegate:(UIPanGestureRecognizer *)delegate
           horizontalTranslation:(CGFloat)horizontalTranslation {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _horizontalTranslation = horizontalTranslation;
  }
  return self;
}

- (UIView *)view {
  return _delegate.view;
}

- (UIGestureRecognizerState)state {
  return _delegate.state;
}

- (CGPoint)translationInView:(UIView *)view {
  return CGPointMake(_horizontalTranslation, 0);
}

- (CGPoint)velocityInView:(UIView *)view {
  return [_delegate velocityInView:view];
}

@end

#pragma mark - NavigationController

@interface NavigationController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate>
@end

@implementation NavigationController {
  bool _isPushingViewController;

  UIGestureRecognizerTarget *_builtinPanGestureRecognizerTarget;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.delegate = self;
  self.interactivePopGestureRecognizer.delegate = self;

  // Get the target method of the UINavigationController's pop gesture recognizer.
  Ivar targetsIVar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
  NSArray *targets = object_getIvar(self.interactivePopGestureRecognizer, targetsIVar);
  _builtinPanGestureRecognizerTarget = targets.firstObject;
}

#pragma mark - UIViewController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
  _isPushingViewController = true;
  [super pushViewController:viewController animated:animated];

  id<TKMViewController> newViewController = (id<TKMViewController>)viewController;
  if ([newViewController respondsToSelector:@selector(canSwipeToGoBack)] &&
      [newViewController canSwipeToGoBack]) {
    UIPanGestureRecognizer *popGestureRecogniser =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePopRecognizer:)];
    popGestureRecogniser.delegate = self;
    [viewController.view addGestureRecognizer:popGestureRecogniser];
  }
}

- (void)handlePopRecognizer:(UIPanGestureRecognizer *)recognizer {
  const CGFloat velocity = [recognizer velocityInView:recognizer.view].x;
  id object = recognizer;

  if (velocity > kVelocityThreshold && (recognizer.state == UIGestureRecognizerStateEnded ||
                                        recognizer.state == UIGestureRecognizerStateCancelled)) {
    object = [[FakeGestureRecognizer alloc] initWithDelegate:recognizer
                                       horizontalTranslation:recognizer.view.frame.size.width];
  }

  // Call the builtin gesture recognizer's selector.
  IMP imp = [_builtinPanGestureRecognizerTarget.target
      methodForSelector:_builtinPanGestureRecognizerTarget.action];
  void (*func)(id, SEL, UIPanGestureRecognizer *) = (void *)imp;
  func(
      _builtinPanGestureRecognizerTarget.target, _builtinPanGestureRecognizerTarget.action, object);
}

- (BOOL)_shouldCrossFadeBottomBars {
  return NO;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
    if (self.viewControllers.count <= 1 || _isPushingViewController) {
      return NO;
    }

    id<TKMViewController> topViewController = (id<TKMViewController>)self.topViewController;
    if ([topViewController respondsToSelector:@selector(canSwipeToGoBack)]) {
      return [topViewController canSwipeToGoBack];
    }
    return NO;
  } else if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
    // Only start when scrolling horizontally. Otherwise it takes priority over vertically scrolling
    // a UITableView.
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint velocity = [pan velocityInView:self.topViewController.view];
    return velocity.x > velocity.y;
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
