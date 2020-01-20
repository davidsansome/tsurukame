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

#import "SubjectCatalogueViewController.h"
#import "Settings.h"
#import "SubjectsByLevelViewController.h"
#import "Tsurukame-Swift.h"

@interface SubjectCatalogueViewController () <UIPageViewControllerDataSource,
                                              UIPageViewControllerDelegate>

@end

@implementation SubjectCatalogueViewController {
  TKMServices *_services;
  int _level;
  UISwitch *_answerSwitch;
}

- (void)setupWithServices:(TKMServices *)services level:(int)level {
  _services = services;
  _level = (int)MIN(level, _services.dataLoader.maxLevelGrantedBySubscription);
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.delegate = self;
  self.dataSource = self;

  _answerSwitch = [[UISwitch alloc] init];
  _answerSwitch.on = Settings.subjectCatalogueViewShowAnswers;
  [_answerSwitch addTarget:self
                    action:@selector(answerSwitchChanged:)
          forControlEvents:UIControlEventValueChanged];
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithCustomView:_answerSwitch];

  [self setViewControllers:@[ [self createViewControllerForLevel:_level] ]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:NO
                completion:nil];
  [self updateNavigationItem];
}

- (void)updateNavigationItem {
  SubjectsByLevelViewController *vc = self.viewControllers.firstObject;
  _level = vc.level;
  self.navigationItem.title = vc.navigationItem.title;
}

- (void)answerSwitchChanged:(UISwitch *)sender {
  SubjectsByLevelViewController *vc = self.viewControllers.firstObject;
  Settings.subjectCatalogueViewShowAnswers = self.showAnswers;
  [vc setShowAnswers:self.showAnswers animated:true];
}

- (bool)showAnswers {
  return _answerSwitch.on;
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)createViewControllerForLevel:(int)level {
  if (level < 1 || level > _services.dataLoader.maxLevelGrantedBySubscription) {
    return nil;
  }
  SubjectsByLevelViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectsByLevel"];
  [vc setupWithServices:_services level:level showAnswers:self.showAnswers];
  [vc setShowAnswers:self.showAnswers animated:false];
  return vc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController {
  SubjectsByLevelViewController *vc = (SubjectsByLevelViewController *)viewController;
  return [self createViewControllerForLevel:vc.level + 1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController {
  SubjectsByLevelViewController *vc = (SubjectsByLevelViewController *)viewController;
  return [self createViewControllerForLevel:vc.level - 1];
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController
         didFinishAnimating:(BOOL)finished
    previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
        transitionCompleted:(BOOL)completed {
  if (!finished || !completed) {
    return;
  }
  [self updateNavigationItem];
}

- (void)pageViewController:(UIPageViewController *)pageViewController
    willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers {
  for (UIViewController *viewController in pendingViewControllers) {
    SubjectsByLevelViewController *vc = (SubjectsByLevelViewController *)viewController;
    [vc setShowAnswers:self.showAnswers animated:NO];
  }
}

@end
