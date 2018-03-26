#import "NavigationController.h"
#import "Style.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController () <WKSubjectDetailsDelegate, NavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet WKSubjectDetailsView *subjectDetailsView;
@property (weak, nonatomic) IBOutlet UILabel *subjectTitle;
@property (weak, nonatomic) IBOutlet UIButton *backButton;

@end

@implementation SubjectDetailsViewController {
  CAGradientLayer *_gradientLayer;
}

- (bool)canSwipeToGoBack {
  return true;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _subjectDetailsView.dataLoader = _dataLoader;
  _subjectDetailsView.delegate = self;
  _subjectDetailsView.showHints = _showHints;
  WKStudyMaterials *studyMaterials = [_localCachingClient getStudyMaterialForID:_subject.id_p];
  [_subjectDetailsView updateWithSubject:_subject studyMaterials:studyMaterials];
  
  for (UIGestureRecognizer *recognizer in _subjectDetailsView.gestureRecognizers) {
    [_subjectDetailsView removeGestureRecognizer:recognizer];
  }
  
  _subjectTitle.attributedText = _subject.japaneseText;
  _gradientLayer = [CAGradientLayer layer];
  _gradientLayer.colors = WKGradientForSubject(_subject);
  [self.view.layer insertSublayer:_gradientLayer atIndex:0];
  
  if (_hideBackButton) {
    [_backButton setHidden:YES];
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  _gradientLayer.frame =
      CGRectMake(0, 0, self.view.bounds.size.width,
                 _subjectTitle.frame.origin.y + _subjectTitle.frame.size.height);
}

- (IBAction)backButtonPressed:(id)sender {
  [self.navigationController popViewControllerAnimated:YES];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (void)openSubject:(WKSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  vc.dataLoader = _dataLoader;
  vc.localCachingClient = _localCachingClient;
  vc.subject = subject;
  [self.navigationController pushViewController:vc animated:YES];
}

@end
