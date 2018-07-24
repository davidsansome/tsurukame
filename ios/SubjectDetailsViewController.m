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

#import "NavigationController.h"
#import "Style.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController () <TKMSubjectDelegate, TKMViewController>

@property (weak, nonatomic) IBOutlet TKMSubjectDetailsView *subjectDetailsView;
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
  _subjectDetailsView.subjectDelegate = self;
  _subjectDetailsView.showHints = _showHints;
  TKMStudyMaterials *studyMaterials = [_localCachingClient getStudyMaterialForID:_subject.id_p];
  TKMAssignment *assignment = nil;
  if (_showUserProgress) {
    assignment = [_localCachingClient getAssignmentForID:_subject.id_p];
  }
  [_subjectDetailsView updateWithSubject:_subject
                          studyMaterials:studyMaterials
                              assignment:assignment];
  
  _subjectTitle.attributedText = [_subject japaneseTextWithImageSize:40.f];
  _gradientLayer = [CAGradientLayer layer];
  _gradientLayer.colors = TKMGradientForSubject(_subject);
  [self.view.layer insertSublayer:_gradientLayer atIndex:0];
  
  if (_hideBackButton) {
    _backButton.hidden = YES;
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_subjectDetailsView deselectLastSubjectChipTapped];
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

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  SubjectDetailsViewController *vc =
      [self.storyboard instantiateViewControllerWithIdentifier:@"subjectDetailsViewController"];
  vc.dataLoader = _dataLoader;
  vc.localCachingClient = _localCachingClient;
  vc.subject = subject;
  [self.navigationController pushViewController:vc animated:YES];
}

@end
