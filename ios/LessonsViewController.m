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

#import "LessonsViewController.h"

#import "Extensions/ProtobufExtensions.h"
#import "LessonsPageControl.h"
#import "ReviewItem.h"
#import "SubjectDetailsViewController.h"
#import "Tsurukame-Swift.h"
#import "UIView+SafeAreaInsets.h"

@interface LessonsViewController () <ReviewViewControllerDelegate>
@property(weak, nonatomic) IBOutlet LessonsPageControl *pageControl;
@property(weak, nonatomic) IBOutlet UIButton *backButton;
@property(nonatomic, readonly) NSArray<UIKeyCommand *> *keyCommands;
@end

@implementation LessonsViewController {
  TKMServices *_services;
  NSArray<ReviewItem *> *_items;

  UIPageViewController *_pageController;
  NSInteger _currentPageIndex;

  ReviewViewController *_reviewViewController;
}

- (void)setupWithServices:(id)services items:(NSArray<ReviewItem *> *)items {
  _services = services;
  _items = [items copy];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = TKMStyleColor.background;

  // Create the page controller.
  _pageController = [[UIPageViewController alloc]
      initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
        navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                      options:nil];
  _pageController.dataSource = self;
  _pageController.delegate = self;

  // Set the subjects on the page control.
  NSMutableArray<TKMSubject *> *subjects = [NSMutableArray array];
  for (ReviewItem *item in _items) {
    TKMSubject *subject = [_services.dataLoader loadSubject:item.assignment.subjectId];
    if (!subject) {
      continue;
    }
    [subjects addObject:subject];
  }
  _pageControl.subjects = subjects;

  // Add it as a child view controller, below the back button.
  [self addChildViewController:_pageController];
  [self.view insertSubview:_pageController.view belowSubview:_backButton];
  [_pageController didMoveToParentViewController:self];

  // Hook up the page control.
  [_pageControl addTarget:self
                   action:@selector(pageChanged)
         forControlEvents:UIControlEventValueChanged];

  // Load the first page.
  [_pageController setViewControllers:@[ [self createViewControllerForIndex:0] ]
                            direction:UIPageViewControllerNavigationDirectionForward
                             animated:NO
                           completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [SiriShortcutHelper.shared attachShortcutActivity:self
                                               type:SiriShortcutHelper.ShortcutTypeLessons];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  CGRect safeArea = UIEdgeInsetsInsetRect(self.view.frame, self.view.tkm_safeAreaInsets);
  CGSize pageControlSize = [_pageControl sizeThatFits:CGSizeMake(self.view.frame.size.width, 0)];
  CGRect pageControlFrame = CGRectMake(CGRectGetMinX(safeArea),
                                       CGRectGetMaxY(safeArea) - pageControlSize.height,
                                       safeArea.size.width,
                                       pageControlSize.height);
  _pageControl.frame = pageControlFrame;
  [_pageControl setNeedsLayout];

  CGRect pageControllerFrame = self.view.frame;
  pageControllerFrame.size.height = pageControlFrame.origin.y;
  _pageController.view.frame = pageControllerFrame;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (IBAction)didTapBackButton:(id)sender {
  [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UIPageControl

- (void)pageChanged {
  NSInteger newPageIndex = _pageControl.currentPageIndex;
  if (newPageIndex == _currentPageIndex) {
    return;
  }

  UIViewController *vc = [self createViewControllerForIndex:newPageIndex];
  UIPageViewControllerNavigationDirection direction =
      (newPageIndex > _currentPageIndex) ? UIPageViewControllerNavigationDirectionForward
                                         : UIPageViewControllerNavigationDirectionReverse;
  [_pageController setViewControllers:@[ vc ] direction:direction animated:YES completion:nil];
  _currentPageIndex = newPageIndex;
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController
         didFinishAnimating:(BOOL)finished
    previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
        transitionCompleted:(BOOL)completed {
  NSInteger index = [self indexOfViewController:_pageController.viewControllers[0]];
  _pageControl.currentPageIndex = index;
  _currentPageIndex = index;
}

#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)createViewControllerForIndex:(NSInteger)index {
  if (index == _items.count) {
    if (_reviewViewController == nil) {
      _reviewViewController =
          [self.storyboard instantiateViewControllerWithIdentifier:@"reviewViewController"];
      [_reviewViewController setupWithServices:_services
                                         items:_items
                                showMenuButton:NO
                            showSubjectHistory:NO
                                      delegate:self];
    }
    return _reviewViewController;
  } else if (index < 0 || index > _items.count) {
    return nil;
  }

  ReviewItem *item = _items[index];
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  [vc setupWithServices:_services
                subject:[_services.dataLoader loadSubject:item.assignment.subjectId]
              showHints:YES
         hideBackButton:YES
                  index:index];
  return vc;
}

- (NSInteger)indexOfViewController:(UIViewController *)viewController {
  if ([viewController.class isSubclassOfClass:[SubjectDetailsViewController class]]) {
    SubjectDetailsViewController *subjectDetailsViewController =
        (SubjectDetailsViewController *)viewController;
    return subjectDetailsViewController.index;
  } else if ([viewController.class isSubclassOfClass:[ReviewViewController class]]) {
    return _items.count;
  }
  return 0;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController {
  return [self createViewControllerForIndex:[self indexOfViewController:viewController] + 1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController {
  return [self createViewControllerForIndex:[self indexOfViewController:viewController] - 1];
}

#pragma mark - ReviewViewControllerDelegate

- (BOOL)reviewViewControllerAllowsCheatsForReviewItem:(ReviewItem *)reviewItem {
  return false;
}

- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController {
  [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
}

- (BOOL)reviewViewControllerAllowsCustomFonts {
  return false;
}

- (BOOL)reviewViewControllerShowsSuccessRate {
  return false;
}

#pragma mark - Keyboard navigation

- (BOOL)canBecomeFirstResponder {
  return true;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
  // No keyboard nav on the quiz page, answer the quiz
  if (_pageControl.currentPageIndex == _items.count) {
    return @[];
  }

  return @[
    [UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow
                        modifierFlags:0
                               action:@selector(prevPage)
                 discoverabilityTitle:@"Previous"],
    [UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow
                        modifierFlags:0
                               action:@selector(nextPage)
                 discoverabilityTitle:@"Next"],
    [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:0 action:@selector(nextPage)],
    [UIKeyCommand keyCommandWithInput:@" "
                        modifierFlags:0
                               action:@selector(playAudio)
                 discoverabilityTitle:@"Play reading"]

  ];
}

- (void)nextPage {
  if (_pageControl.currentPageIndex < [_items count]) {
    _pageControl.currentPageIndex += 1;
    [self pageChanged];
  }
}

- (void)prevPage {
  if (_pageControl.currentPageIndex > 0) {
    _pageControl.currentPageIndex -= 1;
    [self pageChanged];
  }
}

- (void)playAudio {
  UIViewController *vc = _pageController.viewControllers[0];
  if ([vc isKindOfClass:SubjectDetailsViewController.class]) {
    [(SubjectDetailsViewController *)vc playAudio];
  }
}

@end
