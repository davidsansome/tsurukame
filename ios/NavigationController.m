#import "NavigationController.h"

@interface NavigationController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate>
@end

@implementation NavigationController {
  bool _isPushingViewController;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.delegate = self;
  self.interactivePopGestureRecognizer.delegate = self;
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
  _isPushingViewController = true;
  [super pushViewController:viewController animated:animated];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  if (![gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
    return YES;
  }
  if (self.viewControllers.count <= 1 || _isPushingViewController) {
    return NO;
  }
  
  id<NavigationControllerDelegate> topViewController =
      (id<NavigationControllerDelegate>)self.topViewController;
  if ([topViewController respondsToSelector:@selector(canSwipeToGoBack)]) {
    return [topViewController canSwipeToGoBack];
  }
  return NO;
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
  _isPushingViewController = false;
}

@end
