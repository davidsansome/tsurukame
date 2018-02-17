#import "LessonsViewController.h"

#import "SubjectDetailsViewController.h"

@interface LessonsViewController ()
@end

@implementation LessonsViewController {
  NSInteger _currentPageIndex;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _currentPageIndex = 0;
    self.dataSource = self;
    self.delegate = self;
  }
  return self;
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
       transitionCompleted:(BOOL)completed {
  SubjectDetailsViewController *vc = (SubjectDetailsViewController *)self.viewControllers[0];
  _currentPageIndex = vc.index;
}

#pragma mark - UIPageViewControllerDataSource

- (void)setItems:(NSArray<ReviewItem *> *)items {
  assert([NSThread isMainThread]);
  _items = items;
  [self setViewControllers:@[[self createViewControllerForIndex:0]]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:NO
                completion:nil];
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
  return _items.count;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
  return _currentPageIndex;
}

- (UIViewController *)createViewControllerForIndex:(NSInteger)index {
  if (index < 0 || index >= _items.count) {
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

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController {
  SubjectDetailsViewController *subjectDetailsViewController =
      (SubjectDetailsViewController *)viewController;
  NSInteger nextIndex = subjectDetailsViewController.index + 1;
  
  return [self createViewControllerForIndex:nextIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController {
  SubjectDetailsViewController *subjectDetailsViewController =
      (SubjectDetailsViewController *)viewController;
  NSInteger previousIndex = subjectDetailsViewController.index - 1;
  
  return [self createViewControllerForIndex:previousIndex];
}

@end
