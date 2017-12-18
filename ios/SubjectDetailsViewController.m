#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController ()

@property (weak, nonatomic) IBOutlet WKSubjectDetailsView *subjectDetailsView;

@end

@implementation SubjectDetailsViewController

- (void)viewDidLoad {
  _subjectDetailsView.dataLoader = _dataLoader;
  _subjectDetailsView.subject = _subject;
  _subjectDetailsView.owner = self;
  
  self.navigationController.navigationBarHidden = NO;
  
  [super viewDidLoad];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  [_subjectDetailsView prepareSegue:segue];
}

@end
