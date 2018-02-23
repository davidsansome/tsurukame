#import "LessonsViewController.h"

#import "LessonsPageControl.h"
#import "ReviewViewController.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

@interface LessonsViewController () <ReviewViewControllerDelegate>
@property (weak, nonatomic) IBOutlet LessonsPageControl *pageControl;
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
  
  // Add it as a child view controller.
  [self addChildViewController:_pageController];
  [self.view addSubview:_pageController.view];
  [_pageController didMoveToParentViewController:self];
  
  // Hook up the page control.
  [_pageControl addTarget:self
                   action:@selector(pageChanged)
         forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  
  CGRect safeArea = UIEdgeInsetsInsetRect(self.view.frame, self.view.safeAreaInsets);
  CGSize pageControlSize = _pageControl.intrinsicContentSize;
  CGRect pageControlFrame = CGRectMake(CGRectGetMinX(safeArea),
                                       CGRectGetMaxY(safeArea) - pageControlSize.height,
                                       safeArea.size.width,
                                       pageControlSize.height);
  _pageControl.frame = pageControlFrame;
  
  CGRect pageControllerFrame = self.view.frame;
  pageControllerFrame.size.height = pageControlFrame.origin.y;
  _pageController.view.frame = pageControllerFrame;
}

- (void)setItems:(NSArray<ReviewItem *> *)items {
  _items = items;
  
  // Set the subjects on the page control.
  NSMutableArray<WKSubject *> *subjects = [NSMutableArray array];
  for (ReviewItem *item in items) {
    WKSubject *subject = [_dataLoader loadSubject:item.assignment.subjectId];
    [subjects addObject:subject];
  }
  _pageControl.subjects = subjects;
  
  // Load the first page.
  [_pageController setViewControllers:@[[self createViewControllerForIndex:0]]
                            direction:UIPageViewControllerNavigationDirectionForward
                             animated:NO
                           completion:nil];
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
      [_reviewViewController startReviewWithItems:_items];
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

- (void)reviewViewController:(ReviewViewController *)reviewViewController
          finishedReviewItem:(ReviewItem *)reviewItem {
  [_localCachingClient sendProgress:@[reviewItem.answer] handler:nil];
}

- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController {
  [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
}

- (void)reviewViewControllerTappedBackButton:(ReviewViewController *)reviewViewController {
  [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
}

@end
