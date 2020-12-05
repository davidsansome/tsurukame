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

#import "SubjectDetailsViewController.h"

#import "NavigationController.h"
#import "Tables/TKMSubjectModelItem.h"
#import "Tsurukame-Swift.h"

#import "Extensions/ProtobufExtensions.h"

#import <WebKit/WebKit.h>

@interface SubjectDetailsViewController () <TKMSubjectDelegate, TKMViewController>

@property(weak, nonatomic) IBOutlet TKMSubjectDetailsView *subjectDetailsView;
@property(weak, nonatomic) IBOutlet UILabel *subjectTitle;
@property(weak, nonatomic) IBOutlet UIButton *backButton;

@end

@implementation SubjectDetailsViewController {
  TKMServices *_services;
  BOOL _showHints;
  BOOL _hideBackButton;
  TKMSubject *_subject;
  CAGradientLayer *_gradientLayer;
}

- (void)setupWithServices:(TKMServices *)services
                  subject:(TKMSubject *)subject
                showHints:(BOOL)showHints
           hideBackButton:(BOOL)hideBackButton
                    index:(NSInteger)index {
  _services = services;
  _subject = subject;
  _showHints = showHints;
  _hideBackButton = hideBackButton;
  _index = index;
}

- (void)setupWithServices:(TKMServices *)services subject:(TKMSubject *)subject {
  [self setupWithServices:services subject:subject showHints:NO hideBackButton:NO index:0];
}

- (bool)canSwipeToGoBack {
  return true;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [_subjectDetailsView setupWithServices:_services delegate:self];

  TKMStudyMaterials *studyMaterials =
      [_services.localCachingClient getStudyMaterialWithId:_subject.id_p];
  TKMAssignment *assignment = [_services.localCachingClient getAssignmentWithId:_subject.id_p];
  [_subjectDetailsView updateWithSubject:_subject
                          studyMaterials:studyMaterials
                              assignment:assignment
                                    task:nil];

  _subjectTitle.font = [TKMStyle japaneseFontWithSize:_subjectTitle.font.pointSize];
  _subjectTitle.attributedText = [_subject japaneseTextWithImageSize:40.f];
  _gradientLayer = [CAGradientLayer layer];
  _gradientLayer.colors = [TKMStyle gradientForSubject:_subject];
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
  _gradientLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width,
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
  [vc setupWithServices:_services subject:subject];
  [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Keyboard navigation

- (BOOL)canBecomeFirstResponder {
  return true;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
  return @[
    [UIKeyCommand keyCommandWithInput:@" "
                        modifierFlags:0
                               action:@selector(playAudio)
                 discoverabilityTitle:@"Play reading"],
    [UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow
                        modifierFlags:0
                               action:@selector(backButtonPressed:)
                 discoverabilityTitle:@"Back"]
  ];
}

- (void)playAudio {
  [_subjectDetailsView playAudio];
}

@end
