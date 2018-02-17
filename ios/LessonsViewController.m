#import "LessonsViewController.h"

#import "Style.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

static const CGSize kPageControlPageSize = {26.f, 26.f};
static const UIEdgeInsets kPageControlLabelInsets = {1.f, 1.f, 1.f, 1.f};  // top, left, bottom, right
static const CGFloat kPageControlSpacing = 8.f;
static const CGFloat kPageControlPageCornerRadius = 8.f;

@interface LessonsViewController ()
@end

@implementation LessonsViewController {
  NSInteger _currentPageIndex;
  __weak UIPageControl *_pageControl;
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

- (void)viewDidLoad {
  for (NSInteger i = 0; i < self.view.subviews.count; ++i) {
    UIView *subview = self.view.subviews[i];
    if ([subview isKindOfClass:UIPageControl.class]) {
      _pageControl = (UIPageControl *)subview;
      break;
    }
  }
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  
  [_pageControl layoutIfNeeded];
  
  CGFloat totalWidth = _items.count * kPageControlPageSize.width +
                       (_items.count - 1) * kPageControlSpacing;
  CGRect pageFrame = CGRectMake((_pageControl.bounds.size.width - totalWidth) / 2,
                                (_pageControl.bounds.size.height - kPageControlPageSize.height) / 2,
                                kPageControlPageSize.width,
                                kPageControlPageSize.height);
  
  // Remove all existing subviews (the little dots).
  for (UIView *subview in _pageControl.subviews) {
    [subview removeFromSuperview];
  }
  
  // Add new kanji subviews.
  for (NSInteger i = 0; i < _items.count; ++i) {
    ReviewItem *item = _items[i];
    WKSubject *subject = [_dataLoader loadSubject:item.assignment.subjectId];
    
    CGRect gradientFrame = pageFrame;
    CGRect labelFrame = UIEdgeInsetsInsetRect(pageFrame, kPageControlLabelInsets);
    
    UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
    label.minimumScaleFactor = 0.2;
    label.adjustsFontSizeToFitWidth = YES;
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.attributedText = [subject japaneseTextWithImageSize:kPageControlPageSize.width];
    label.textColor = [UIColor whiteColor];
    
    UIView *gradientView = [[UIView alloc] initWithFrame:gradientFrame];
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = gradientView.bounds;
    gradientLayer.cornerRadius = kPageControlPageCornerRadius;
    gradientLayer.masksToBounds = YES;
    gradientLayer.colors = WKGradientForSubject(subject);
    [gradientView.layer insertSublayer:gradientLayer atIndex:0];
    
    [_pageControl addSubview:gradientView];
    [_pageControl addSubview:label];
    
    pageFrame.origin.x += kPageControlPageSize.width + kPageControlSpacing;
  }
  [self setPageLabelAlpha];
}

- (void)setPageLabelAlpha {
  for (NSInteger i = 0; i < _items.count; ++i) {
    CGFloat alpha = (i == _currentPageIndex) ? 1.0 : 0.5;
    UIView *gradientView = (UILabel *)_pageControl.subviews[i * 2];
    UIView *label = (UILabel *)_pageControl.subviews[i * 2 + 1];
    gradientView.alpha = alpha;
    label.alpha = alpha;
  }
}

#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
       transitionCompleted:(BOOL)completed {
  SubjectDetailsViewController *vc = (SubjectDetailsViewController *)self.viewControllers[0];
  _currentPageIndex = vc.index;
  [self setPageLabelAlpha];
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
