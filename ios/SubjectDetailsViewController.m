#import "Style.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController () <WKSubjectDetailsLinkHandler>

@property (weak, nonatomic) IBOutlet WKSubjectDetailsView *subjectDetailsView;
@property (weak, nonatomic) IBOutlet UILabel *subjectTitle;

@end

@implementation SubjectDetailsViewController {
  CAGradientLayer *_gradientLayer;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _subjectDetailsView.dataLoader = _dataLoader;
  _subjectDetailsView.linkHandler = self;
  WKStudyMaterials *studyMaterials = [_localCachingClient getStudyMaterialForID:_subject.id_p];
  [_subjectDetailsView updateWithSubject:_subject studyMaterials:studyMaterials];
  _subjectTitle.text = _subject.japanese;
  
  _gradientLayer = [CAGradientLayer layer];
  _gradientLayer.colors = WKGradientForSubject(_subject);
  [self.view.layer insertSublayer:_gradientLayer atIndex:0];
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
