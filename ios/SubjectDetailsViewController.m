#import "Style.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController () <WKSubjectDetailsLinkHandler>

@property (weak, nonatomic) IBOutlet WKSubjectDetailsView *subjectDetailsView;

@end

@implementation SubjectDetailsViewController {
  CAGradientLayer *_gradientLayer;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _subjectDetailsView.dataLoader = _dataLoader;
  _subjectDetailsView.subject = _subject;
  _subjectDetailsView.linkHandler = self;
  self.navigationItem.title = _subject.japanese;
  
  _gradientLayer = [CAGradientLayer layer];
  _gradientLayer.colors = WKGradientForSubject(_subject);
  [self.view.layer insertSublayer:_gradientLayer atIndex:0];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  _gradientLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.safeAreaInsets.top);
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

- (void)openSubject:(WKSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  vc.dataLoader = _dataLoader;
  vc.subject = subject;
  [self.navigationController pushViewController:vc animated:YES];
}

@end
