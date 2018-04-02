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
