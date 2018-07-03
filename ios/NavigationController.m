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

#import "Style.h"

static const NSTimeInterval kPopTransitionDuration = 0.8f;

// Starting horizontal offset for the incoming view.
static const CGFloat kPopToViewHorizontalOffset = -60.f;

// Speed (in points/sec) the user has to fling the view to finish the animation.
static const CGFloat kVelocityThreshold = 60.f;

// Shadow on the outgoing view.
static const CGFloat kShadowOpacity = 0.25f;
static const CGFloat kShadowRadius = 5.f;

@interface NavigationController () <UIGestureRecognizerDelegate,
                                    UIViewControllerAnimatedTransitioning,
                                    UINavigationControllerDelegate>
@end

@implementation NavigationController {
  bool _isPushingViewController;
  
  UIPercentDrivenInteractiveTransition *_currentPopTransition;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.delegate = self;
  self.interactivePopGestureRecognizer.delegate = self;
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
    [viewController.view addGestureRecognizer:popGestureRecogniser];
  }
}

- (void)handlePopRecognizer:(UIPanGestureRecognizer *)recognizer {
  const CGFloat translation = [recognizer translationInView:recognizer.view].x;
  const CGFloat velocity = [recognizer velocityInView:recognizer.view].x;
  const CGFloat progress = translation / recognizer.view.bounds.size.width;
  
  switch (recognizer.state) {
    case UIGestureRecognizerStateBegan:
      _currentPopTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
      [self popViewControllerAnimated:YES];
      
      // Fallthrough.
    case UIGestureRecognizerStateChanged:
      [_currentPopTransition updateInteractiveTransition:progress];
      break;
      
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
      if (velocity > kVelocityThreshold) {
        [_currentPopTransition finishInteractiveTransition];
      } else {
        [_currentPopTransition cancelInteractiveTransition];
      }
    
      _currentPopTransition = nil;
      break;
      
    default:
      break;
  }
}

- (BOOL)_shouldCrossFadeBottomBars {
  return NO;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  if (![gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
    return YES;
  }
  if (self.viewControllers.count <= 1 || _isPushingViewController) {
    return NO;
  }
  
  id<TKMViewController> topViewController = (id<TKMViewController>)self.topViewController;
  if ([topViewController respondsToSelector:@selector(canSwipeToGoBack)]) {
    return [topViewController canSwipeToGoBack];
  }
  return NO;
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
  _isPushingViewController = false;
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC {
  if (operation == UINavigationControllerOperationPop && _currentPopTransition) {
    return self;
  }
  return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                         interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController {
  return _currentPopTransition;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
  return kPopTransitionDuration;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
  UIViewController *outgoingVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
  UIViewController *incomingVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
  
  // Calculate the frames for the views.
  CGRect incomingFinalFrame = [transitionContext finalFrameForViewController:incomingVC];
  CGRect incomingInitialFrame = CGRectOffset(incomingFinalFrame, kPopToViewHorizontalOffset, 0.f);
  CGRect outgoingInitialFrame = outgoingVC.view.frame;
  CGRect outgoingFinalFrame = CGRectOffset(outgoingInitialFrame,
                                           outgoingInitialFrame.size.width, 0.f);
  
  // Add the incoming and outgoing views to the container.
  UIView *containerView = [transitionContext containerView];
  [containerView addSubview:incomingVC.view];
  [containerView bringSubviewToFront:outgoingVC.view];
  
  // Use a black overlay to dim the incoming view.
  UIView *blackOverlayView = [[UIView alloc] initWithFrame:incomingFinalFrame];
  blackOverlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2f];
  blackOverlayView.alpha = 1.f;
  [containerView insertSubview:blackOverlayView aboveSubview:incomingVC.view];
  
  // Give the outgoing view a shadow.
  UIView *shadowView = [[UIView alloc] initWithFrame:outgoingInitialFrame];
  shadowView.backgroundColor = [UIColor whiteColor];
  TKMAddShadowToView(shadowView, 0, kShadowOpacity, kShadowRadius);
  [containerView insertSubview:shadowView aboveSubview:blackOverlayView];
  
  // Set initial positions.
  incomingVC.view.frame = incomingInitialFrame;
  
  [UIView animateWithDuration:kPopTransitionDuration
                        delay:0.f
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     blackOverlayView.alpha = 0.f;
                     incomingVC.view.frame = incomingFinalFrame;
                     outgoingVC.view.frame = outgoingFinalFrame;
                     shadowView.frame = outgoingFinalFrame;
                   } completion:^(BOOL finished) {
                     [blackOverlayView removeFromSuperview];
                     [transitionContext completeTransition:!transitionContext.transitionWasCancelled];
                     
                     // Fade out the shadow before removing it.
                     [UIView animateWithDuration:0.4f animations:^{
                       shadowView.alpha = 0.f;
                     } completion:^(BOOL finished) {
                       [shadowView removeFromSuperview];
                     }];
                   }];
}

@end
