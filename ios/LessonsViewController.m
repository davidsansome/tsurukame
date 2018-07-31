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

#import "LessonsPageControl.h"
#import "ReviewViewController.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"
#import "UIView+SafeAreaInsets.h"

@interface LessonsViewController () <ReviewViewControllerDelegate>
@property (weak, nonatomic) IBOutlet LessonsPageControl *pageControl;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@end

@implementation LessonsViewController {
  UIPageViewController *_pageController;
  NSInteger _currentPageIndex;
  
  ReviewViewController *_reviewViewController;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  // Create the page controller.
  _pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
  _pageController.dataSource = self;
  _pageController.delegate = self;
  
  // Set the subjects on the page control.
  NSMutableArray<TKMSubject *> *subjects = [NSMutableArray array];
  for (ReviewItem *item in _items) {
    TKMSubject *subject = [_dataLoader loadSubject:item.assignment.subjectId];
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
  [_pageController setViewControllers:@[[self createViewControllerForIndex:0]]
                            direction:UIPageViewControllerNavigationDirectionForward
                             animated:NO
                           completion:nil];
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
  [_pageController setViewControllers:@[vc]
                            direction:direction
                             animated:YES
                           completion:nil];
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
      _reviewViewController.dataLoader = _dataLoader;
      _reviewViewController.localCachingClient = _localCachingClient;
      _reviewViewController.delegate = self;
      _reviewViewController.hideBackButton = true;
      _reviewViewController.items = _items;
    }
    return _reviewViewController;
  } else if (index < 0 || index > _items.count) {
    return nil;
  }
  
  ReviewItem *item = _items[index];
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  vc.dataLoader = _dataLoader;
  vc.localCachingClient = _localCachingClient;
  vc.showHints = true;
  vc.hideBackButton = true;
  vc.subject = [_dataLoader loadSubject:item.assignment.subjectId];
  vc.index = index;
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

- (bool)reviewViewController:(ReviewViewController *)reviewViewController
             allowsCheatsFor:(ReviewItem *)reviewItem {
  return false;
}

- (bool)reviewViewControllerShowsSubjectHistory:(ReviewViewController *)reviewViewController {
  return false;
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
          finishedReviewItem:(ReviewItem *)reviewItem {
  [_localCachingClient sendProgress:@[reviewItem.answer]];
}

- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController {
  [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
            tappedBackButton:(UIButton *)button {
  [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
}

@end
