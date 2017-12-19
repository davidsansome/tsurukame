#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController () <WKSubjectDetailsLinkHandler>

@property (weak, nonatomic) IBOutlet WKSubjectDetailsView *subjectDetailsView;

@end

@implementation SubjectDetailsViewController

- (void)viewDidLoad {
  _subjectDetailsView.dataLoader = _dataLoader;
  _subjectDetailsView.subject = _subject;
  _subjectDetailsView.linkHandler = self;
  self.navigationItem.title = _subject.japanese;
  
  [super viewDidLoad];
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
