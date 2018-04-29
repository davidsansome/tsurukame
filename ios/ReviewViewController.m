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

#import "AnswerChecker.h"
#import "NSMutableArray+Shuffle.h"
#import "ReviewSummaryViewController.h"
#import "ReviewViewController.h"
#import "Style.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "SuccessAnimation.h"
#import "UserDefaults.h"
#import "WKKanaInput.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

static const NSTimeInterval kAnimationDuration = 0.25f;
static const CGFloat kSpacingFromKeyboard = 0.f;

static NSArray<id> *kReadingGradient;
static NSArray<id> *kMeaningGradient;
static UIColor *kReadingTextColor;
static UIColor *kMeaningTextColor;
static UIColor *kDefaultButtonTintColor;


@interface ReviewViewController () <UITextFieldDelegate, WKSubjectDetailsDelegate>

@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIView *questionBackground;
@property (weak, nonatomic) IBOutlet UIView *promptBackground;
@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UILabel *promptLabel;
@property (weak, nonatomic) IBOutlet UITextField *answerField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UIButton *addSynonymButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet WKSubjectDetailsView *subjectDetailsView;

@property (weak, nonatomic) IBOutlet UILabel *successRateLabel;
@property (weak, nonatomic) IBOutlet UILabel *doneLabel;
@property (weak, nonatomic) IBOutlet UILabel *queueLabel;
@property (weak, nonatomic) IBOutlet UIImageView *successRateIcon;
@property (weak, nonatomic) IBOutlet UIImageView *doneIcon;
@property (weak, nonatomic) IBOutlet UIImageView *queueIcon;

@property (nonatomic) IBOutlet NSLayoutConstraint *answerFieldToBottomConstraint;
@property (nonatomic) IBOutlet NSLayoutConstraint *answerFieldToSubjectDetailsViewConstraint;

@end

@implementation ReviewViewController {
  WKKanaInput *_kanaInput;
  id<ReviewViewControllerDelegate> _defaultDelegate;

  NSMutableArray<ReviewItem *> *_activeQueue;
  NSMutableArray<ReviewItem *> *_reviewQueue;
  NSMutableArray<ReviewItem *> *_completedReviews;
  int _activeQueueSize;

  int _activeTaskIndex;  // An index into activeQueue;
  WKTaskType _activeTaskType;
  ReviewItem *_activeTask;
  WKSubject *_activeSubject;
  WKStudyMaterials *_activeStudyMaterials;

  int _tasksAnsweredCorrectly;
  int _tasksAnswered;

  CAGradientLayer *_questionGradient;
  CAGradientLayer *_promptGradient;
  bool _inAnimation;
  
  // We don't adjust the bottom constraint after the view appeared the first time - some keyboards
  // (gboard) change size a lot.
  bool _viewDidAppearOnce;
  
  UIImpactFeedbackGenerator *_hapticGenerator;
}

#pragma mark - Constructors

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kReadingGradient = @[(id)[UIColor colorWithRed:0.235f green:0.235f blue:0.235f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.102f green:0.102f blue:0.102f alpha:1.0f].CGColor];
    kMeaningGradient = @[(id)[UIColor colorWithRed:0.933f green:0.933f blue:0.933f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.882f green:0.882f blue:0.882f alpha:1.0f].CGColor];
    kReadingTextColor = [UIColor whiteColor];
    kMeaningTextColor = [UIColor colorWithRed:0.333f green:0.333f blue:0.333f alpha:1.0f];
    kDefaultButtonTintColor = [[[UIButton alloc] init] tintColor];
  });
  
  self = [super initWithCoder:aDecoder];
  if (self) {
    _kanaInput = [[WKKanaInput alloc] initWithDelegate:self];
    _defaultDelegate = [[DefaultReviewViewControllerDelegate alloc] init];
    _delegate = _defaultDelegate;
    _hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    
    UIKeyCommand *enterCommand =
        [UIKeyCommand keyCommandWithInput:@"\r"
                            modifierFlags:0
                                   action:@selector(enterKeyPressed)];
    [self addKeyCommand:enterCommand];
  }
  return self;
}

#pragma mark - Public methods

- (void)setDelegate:(id<ReviewViewControllerDelegate>)delegate {
  if (delegate != _defaultDelegate) {
    _defaultDelegate = nil;
  }
  _delegate = delegate;
}

- (void)setItems:(NSArray<ReviewItem *> *)items {
  _reviewQueue = [NSMutableArray arrayWithArray:items];
  _activeQueue = [NSMutableArray array];
  _completedReviews = [NSMutableArray array];
  
  if (UserDefaults.groupMeaningReading) {
    _activeQueueSize = 1;
  } else {
    // TODO: Make this configurable.
    _activeQueueSize = 5;
  }
  
  [_reviewQueue shuffle];
  switch (UserDefaults.reviewOrder) {
    case ReviewOrder_Random:
      break;
    case ReviewOrder_BySRSLevel:
      [_reviewQueue sortUsingComparator:^NSComparisonResult(ReviewItem *a, ReviewItem *b) {
        if (a.assignment.srsStage < b.assignment.srsStage) return NSOrderedAscending;
        if (a.assignment.srsStage > b.assignment.srsStage) return NSOrderedDescending;
        if (a.assignment.subjectType < b.assignment.subjectType) return NSOrderedAscending;
        if (a.assignment.subjectType > b.assignment.subjectType) return NSOrderedDescending;
        return NSOrderedSame;
      }];
      break;
    case ReviewOrder_CurrentLevelFirst:
      [_reviewQueue sortUsingComparator:^NSComparisonResult(ReviewItem *a, ReviewItem *b) {
        if (a.assignment.level < b.assignment.level) return NSOrderedDescending;
        if (a.assignment.level > b.assignment.level) return NSOrderedAscending;
        if (a.assignment.subjectType < b.assignment.subjectType) return NSOrderedAscending;
        if (a.assignment.subjectType > b.assignment.subjectType) return NSOrderedDescending;
        return NSOrderedSame;
      }];
      break;
  }
  
  [self refillActiveQueue];
}

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  WKAddShadowToView(_questionLabel, 1, 0.2, 4);
  
  _questionGradient = [CAGradientLayer layer];
  [_questionBackground.layer addSublayer:_questionGradient];
  _promptGradient = [CAGradientLayer layer];
  [_promptBackground.layer addSublayer:_promptGradient];
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(keyboardWillShow:)
             name:UIKeyboardWillShowNotification
           object:nil];
  
  _subjectDetailsView.dataLoader = _dataLoader;
  _subjectDetailsView.delegate = self;
  
  _answerField.delegate = _kanaInput;
  [_answerField addTarget:self
                   action:@selector(answerFieldValueDidChange)
         forControlEvents:UIControlEventEditingChanged];
  
  if (_hideBackButton) {
    _backButton.hidden = YES;
  }
  
  [self viewDidLayoutSubviews];
  [self randomTask];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  
  // Set the prompt's frame straight away - we don't care about animating it.
  _promptGradient.frame = _promptBackground.bounds;

  // 'frame' is a derived property.  Set it so the CALayer calculates 'bounds' and 'position' for
  // us, then animate those animatable properties from the old values to the new values.
  CGRect oldBounds = _questionGradient.bounds;
  CGPoint oldPosition = _questionGradient.position;
  _questionGradient.frame = _questionBackground.bounds;
  CGRect newBounds = _questionGradient.bounds;
  CGPoint newPosition = _questionGradient.position;
  
  if (!_inAnimation) {
    return;
  }

  // Animate bounds.  
  CABasicAnimation *boundsAnimation = [CABasicAnimation animationWithKeyPath:@"bounds"];
  boundsAnimation.duration = kAnimationDuration;
  boundsAnimation.timingFunction =
      [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  boundsAnimation.fromValue = [NSValue valueWithCGRect:oldBounds];
  boundsAnimation.toValue = [NSValue valueWithCGRect:newBounds];
  [_questionGradient addAnimation:boundsAnimation forKey:nil];
  
  // Set position straight away with no animation.  Position is in some other
  // non-screen space, so even though we're not moving it on screen, we need to
  // jump to the new position immediately.
  CABasicAnimation *positionAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
  positionAnimation.duration = 0;
  positionAnimation.timingFunction =
      [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  positionAnimation.fromValue = [NSValue valueWithCGPoint:oldPosition];
  positionAnimation.toValue = [NSValue valueWithCGPoint:newPosition];
  [_questionGradient addAnimation:positionAnimation forKey:nil];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  _viewDidAppearOnce = true;
  dispatch_async(dispatch_get_main_queue(), ^{
    [_answerField becomeFirstResponder];
  });
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

#pragma mark - Event handlers

- (void)keyboardWillShow:(NSNotification *)notification {
  if (!_viewDidAppearOnce) {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect viewFrame = [self.view.superview convertRect:self.view.frame
                                                 toView:self.view.window.rootViewController.view];
    CGFloat offset = CGRectGetMaxY(viewFrame) - keyboardFrame.origin.y;
    _answerFieldToBottomConstraint.constant = offset + kSpacingFromKeyboard;
  }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"reviewSummary"]) {
    ReviewSummaryViewController *vc = (ReviewSummaryViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    vc.items = _completedReviews;
  } else if ([segue.identifier isEqualToString:@"subjectDetails"]) {
    SubjectDetailsViewController *vc = (SubjectDetailsViewController *)segue.destinationViewController;
    vc.showUserProgress = true;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    vc.subject = _subjectDetailsView.lastSubjectClicked;
  }
}

#pragma mark - Setup

- (void)refillActiveQueue {
  if (_wrappingUp) {
    [self updateWrapUpButton];
    return;
  }
  while (_activeQueue.count < _activeQueueSize &&
         _reviewQueue.count != 0) {
    ReviewItem *item = [_reviewQueue firstObject];
    [_reviewQueue removeObjectAtIndex:0];
    [_activeQueue addObject:item];
  }
}

- (void)setWrappingUp:(bool)wrappingUp {
  _wrappingUp = wrappingUp;
  [self updateWrapUpButton];
}

- (void)updateWrapUpButton {
  NSString *title;
  if (_wrappingUp) {
    title = [NSString stringWithFormat:@"Back (%lu)", (unsigned long)_activeQueue.count];
  } else {
    title = @"Back";
  }
  [_backButton setTitle:title forState:UIControlStateNormal];
}

- (void)randomTask {
  if (_activeQueue.count == 0) {
    [_delegate reviewViewControllerFinishedAllReviewItems:self];
    return;
  }
  
  // Update the progress labels.
  NSString *successRateText;
  if (_tasksAnswered == 0) {
    successRateText = @"100%";
  } else {
    successRateText = [NSString stringWithFormat:@"%d%%",
                       (int)((double)(_tasksAnsweredCorrectly) / _tasksAnswered * 100)];
  }
  int queueLength = (int)(_activeQueue.count + _reviewQueue.count);
  NSString *doneText = [NSString stringWithFormat:@"%d", _reviewsCompleted];
  NSString *queueText = [NSString stringWithFormat:@"%d", queueLength];
  
  // Update the progress bar.
  int totalLength = queueLength + _reviewsCompleted;
  if (totalLength == 0) {
    [_progressBar setProgress:0.0 animated:YES];
  } else {
    [_progressBar setProgress:(double)(_reviewsCompleted) / totalLength animated:YES];
  }
  
  // Choose a random task from the active queue.
  _activeTaskIndex = arc4random_uniform((uint32_t)_activeQueue.count);
  _activeTask = _activeQueue[_activeTaskIndex];
  _activeSubject = [_dataLoader loadSubject:_activeTask.assignment.subjectId];
  _activeStudyMaterials =
      [_localCachingClient getStudyMaterialForID:_activeTask.assignment.subjectId];
  
  // Choose whether to ask the meaning or the reading.
  if (_activeTask.answeredMeaning) {
    _activeTaskType = kWKTaskTypeReading;
  } else if (_activeTask.answeredReading || _activeSubject.hasRadical) {
    _activeTaskType = kWKTaskTypeMeaning;
  } else if (UserDefaults.groupMeaningReading) {
    _activeTaskType = UserDefaults.meaningFirst ? kWKTaskTypeMeaning : kWKTaskTypeReading;
  } else {
    _activeTaskType = (WKTaskType)arc4random_uniform(kWKTaskType_Max);
  }
  
  // Fill the question labels.
  NSString *subjectTypePrompt;
  NSString *taskTypePrompt;
  NSArray *promptGradient;
  UIColor *promptTextColor;
  
  switch (_activeTask.assignment.subjectType) {
    case WKSubject_Type_Kanji:
      subjectTypePrompt = @"Kanji";
      break;
    case WKSubject_Type_Radical:
      subjectTypePrompt = @"Radical";
      break;
    case WKSubject_Type_Vocabulary:
      subjectTypePrompt = @"Vocabulary";
      break;
  }
  switch (_activeTaskType) {
    case kWKTaskTypeMeaning:
      _kanaInput.enabled = false;
      taskTypePrompt = @"Meaning";
      promptGradient = kMeaningGradient;
      promptTextColor = kMeaningTextColor;
      break;
    case kWKTaskTypeReading:
      _kanaInput.enabled = true;
      taskTypePrompt = @"Reading";
      promptGradient = kReadingGradient;
      promptTextColor = kReadingTextColor;
      break;
    case kWKTaskType_Max:
      assert(false);
  }
  
  UIFont *boldFont = [UIFont boldSystemFontOfSize:self.promptLabel.font.pointSize];
  NSMutableAttributedString *prompt = [[NSMutableAttributedString alloc] initWithString:
                                       [NSString stringWithFormat:@"%@ %@",
                                        subjectTypePrompt, taskTypePrompt]];
  [prompt setAttributes:@{NSFontAttributeName: boldFont}
                  range:NSMakeRange(prompt.length - taskTypePrompt.length, taskTypePrompt.length)];
  
  // Animate the text labels.
  UIViewAnimationOptions options = UIViewAnimationOptionTransitionCrossDissolve;
  [UIView transitionWithView:self.successRateLabel duration:kAnimationDuration options:options animations:^{
    _successRateLabel.text = successRateText;
  } completion:nil];
  [UIView transitionWithView:self.doneLabel duration:kAnimationDuration options:options animations:^{
    _doneLabel.text = doneText;
  } completion:nil];
  [UIView transitionWithView:self.queueLabel duration:kAnimationDuration options:options animations:^{
    _queueLabel.text = queueText;
  } completion:nil];
  [UIView transitionWithView:self.questionLabel duration:kAnimationDuration options:options animations:^{
    _questionLabel.attributedText = _activeSubject.japaneseText;
  } completion:nil];
  [UIView transitionWithView:self.promptLabel duration:kAnimationDuration options:options animations:^{
    _promptLabel.attributedText = prompt;
  } completion:nil];
  [UIView transitionWithView:self.answerField duration:kAnimationDuration options:options animations:^{
    _answerField.text = nil;
  } completion:nil];
  
  // Text color.
  _promptLabel.textColor = promptTextColor;
  
  // Submit button.
  _submitButton.enabled = false;
  
  // Background gradients.
  [CATransaction begin];
  [CATransaction setAnimationDuration:kAnimationDuration];
  _questionGradient.colors = WKGradientForAssignment(_activeTask.assignment);
  _promptGradient.colors = promptGradient;
  [CATransaction commit];
  
  // Accessibility.
  _successRateLabel.accessibilityLabel = [NSString stringWithFormat:@"%@ correct so far",
                                          successRateText];
  _doneLabel.accessibilityLabel = [NSString stringWithFormat:@"%@ done", doneText];
  _queueLabel.accessibilityLabel = [NSString stringWithFormat:@"%@ remaining", queueText];
  _questionLabel.accessibilityLabel = [NSString stringWithFormat:@"Japanese %@. Question",
                                       subjectTypePrompt];

  [self animateSubjectDetailsViewShown:false];
  
  [_answerField becomeFirstResponder];
}

#pragma mark - Animation

- (void)animateSubjectDetailsViewShown:(bool)shown {
  bool cheats = [_delegate reviewViewController:self allowsCheatsFor:_activeTask];
  _answerField.enabled = !shown;

  if (shown) {
    _subjectDetailsView.hidden = NO;
    if (cheats) {
      _addSynonymButton.hidden = NO;
    }
  }

  [self.view layoutIfNeeded];
  [UIView animateWithDuration:kAnimationDuration animations:^{
    // Constraints.  Disable both first then enable the one we want.
    _answerFieldToBottomConstraint.active = false;
    _answerFieldToSubjectDetailsViewConstraint.active = false;
    _answerFieldToBottomConstraint.active = !shown;
    _answerFieldToSubjectDetailsViewConstraint.active = shown;

    // Scale the text in the question label.
    const float scale = shown ? 0.7 : 1.0;
    _questionLabel.transform = CGAffineTransformMakeScale(scale, scale);

    // Fade the controls.
    _subjectDetailsView.alpha = shown ? 1.0 : 0.0;
    if (cheats) {
      _addSynonymButton.alpha = shown ? 1.0 : 0.0;
    }
    
    // Change the background color of the answer field.
    _answerField.textColor = shown ? [UIColor redColor] : [UIColor blackColor];
    
    // We resize the gradient layers in viewDidLayoutSubviews.
    _inAnimation = true;
    [self.view layoutIfNeeded];
    _inAnimation = false;
  } completion:^(BOOL finished) {
    if (!shown) {
      _subjectDetailsView.hidden = YES;
      if (cheats) {
        _addSynonymButton.hidden = YES;
      }
    }
  }];
}

#pragma mark - Back button

- (IBAction)backButtonPressed:(id)sender {
  [_delegate reviewViewController:self tappedBackButton:_backButton];
}

#pragma mark - Submitting answers

- (void)answerFieldValueDidChange {
  NSString *text = _answerField.text;
  text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  _submitButton.enabled = text.length != 0;
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
    replacementString:(NSString *)string {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self answerFieldValueDidChange];
  });
  return YES;
}

- (IBAction)submitButtonPressed:(id)sender {
  [self enterKeyPressed];
}

- (void)enterKeyPressed {
  if (!_submitButton.enabled) {
    return;
  }
  if (!_answerField.enabled) {
    [self randomTask];
  } else {
    [self submit];
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [self submit];
  return YES;
}

- (void)submit {
  WKAnswerCheckerResult result =
      CheckAnswer(_answerField.text, _activeSubject, _activeStudyMaterials, _activeTaskType);
  switch (result) {
    case kWKAnswerPrecise:
    case kWKAnswerImprecise: {
      [self markAnswer:true remark:false];
      break;
    }
    case kWKAnswerIncorrect:
      [self markAnswer:false remark:false];
      break;
    case kWKAnswerOtherKanjiReading:
      [self shakeView:_answerField];
      break;
    case kWKAnswerContainsInvalidCharacters:
      [self shakeView:_answerField];
      break;
  }
}

- (void)shakeView:(UIView *)view {
  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
  animation.duration = 0.1f;
  animation.repeatCount = 3;
  animation.autoreverses = true;
  animation.fromValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x - 10, view.center.y)];
  animation.toValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x + 10, view.center.y)];
  
  [view.layer addAnimation:animation forKey:nil];
}

- (void)markAnswer:(bool)correct remark:(bool)remark {
  if (correct) {
    [_hapticGenerator impactOccurred];
    [_hapticGenerator prepare];
  }
  
  // Mark the task.
  switch (_activeTaskType) {
    case kWKTaskTypeMeaning:
      if (remark || !_activeTask.answer.hasMeaningWrong) {
        _activeTask.answer.meaningWrong = !correct;
      }
      _activeTask.answeredMeaning = correct;
      break;
    case kWKTaskTypeReading:
      if (remark || !_activeTask.answer.hasReadingWrong) {
        _activeTask.answer.readingWrong = !correct;
      }
      _activeTask.answeredReading = correct;
      break;
    case kWKTaskType_Max:
      abort();
  }
  
  // Update stats.
  if (!remark) {
    _tasksAnswered ++;
  }
  if (correct) {
    _tasksAnsweredCorrectly ++;
  }
  
  // Remove it from the active queue if that was the last part.
  bool isSubjectFinished = _activeTask.answeredMeaning && (_activeSubject.hasRadical || _activeTask.answeredReading);
  bool didLevelUp = (!_activeTask.answer.readingWrong && !_activeTask.answer.meaningWrong);
  int newSrsStage = didLevelUp ? _activeTask.assignment.srsStage + 1 : _activeTask.assignment.srsStage - 1;
  if (isSubjectFinished) {
    [_delegate reviewViewController:self finishedReviewItem:_activeTask];
    
    _reviewsCompleted ++;
    [_completedReviews addObject:_activeTask];
    [_activeQueue removeObjectAtIndex:_activeTaskIndex];
    [self refillActiveQueue];
  }
  
  // Show a new task if it was correct.
  if (correct) {
    [self randomTask];
    RunSuccessAnimation(_answerField, _doneLabel, isSubjectFinished, didLevelUp, newSrsStage);
    return;
  }
  
  // Otherwise show the correct answer.
  [_subjectDetailsView updateWithSubject:_activeSubject
                          studyMaterials:_activeStudyMaterials
                              assignment:nil];
  
  [CATransaction begin];
  [CATransaction setAnimationDuration:kAnimationDuration];
  [self animateSubjectDetailsViewShown:true];
  [CATransaction commit];
}

#pragma mark - Ignoring incorrect answers

- (IBAction)addSynonymButtonPressed:(id)sender {
  __weak ReviewViewController *weakSelf = self;
  
  UIAlertController *c =
      [UIAlertController alertControllerWithTitle:@"Ignore incorrect answer?"
                                          message:@"Don't cheat!  Only use this if you promise you "
                                                   "knew the correct answer."
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  c.popoverPresentationController.sourceView = _addSynonymButton;
  c.popoverPresentationController.sourceRect = _addSynonymButton.bounds;

  [c addAction:[UIAlertAction actionWithTitle:@"Ignore typo"
                                        style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction * _Nonnull action) {
                                        ReviewViewController *unsafeSelf = weakSelf;
                                        if (unsafeSelf) {
                                          [unsafeSelf markAnswer:true remark:true];
                                        }
                                      }]];
  if (_activeTaskType == kWKTaskTypeMeaning) {
    [c addAction:[UIAlertAction actionWithTitle:@"Add synonym"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
                                          ReviewViewController *unsafeSelf = weakSelf;
                                          if (unsafeSelf) {
                                            [unsafeSelf addSynonym];
                                            [unsafeSelf markAnswer:true remark:true];
                                          }
                                        }]];
  }
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)addSynonym {
  if (!_activeStudyMaterials) {
    _activeStudyMaterials = [[WKStudyMaterials alloc] init];
    _activeStudyMaterials.subjectId = _activeSubject.id_p;
    _activeStudyMaterials.subjectType = _activeSubject.subjectType;
  }
  [_activeStudyMaterials.meaningSynonymsArray addObject:_answerField.text];
  [_localCachingClient updateStudyMaterial:_activeStudyMaterials];
}

#pragma mark - WKSubjectDetailsDelegate

- (void)openSubject:(WKSubject *)subject {
  [self performSegueWithIdentifier:@"subjectDetails" sender:self];
}

- (void)subjectDetailsView:(WKSubjectDetailsView *)view
       didFinishNavigation:(WKNavigation *)navigation {
  view.hidden = NO;
  view.alpha = 0.0f;
  [UIView animateWithDuration:kAnimationDuration animations:^{
    view.alpha = 1.0f;
  }];
}

@end


@implementation DefaultReviewViewControllerDelegate

- (bool)reviewViewController:(ReviewViewController *)reviewViewController
             allowsCheatsFor:(ReviewItem *)reviewItem {
  return UserDefaults.enableCheats;
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
            tappedBackButton:(UIButton *)backButton {
  if (reviewViewController.reviewsCompleted == 0) {
    [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
    return;
  }
  
  __weak ReviewViewController *weakController = reviewViewController;
  UIAlertController *c =
      [UIAlertController alertControllerWithTitle:@"End review session?"
                                          message:@"You'll lose progress on any half-answered reviews"
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  c.popoverPresentationController.sourceView = backButton;
  c.popoverPresentationController.sourceRect = backButton.bounds;
  
  [c addAction:[UIAlertAction actionWithTitle:@"End review session"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction * _Nonnull action) {
                                        [weakController performSegueWithIdentifier:@"reviewSummary"
                                                                            sender:weakController];
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  if (reviewViewController.wrappingUp) {
    [c addAction:[UIAlertAction actionWithTitle:@"Cancel wrap up"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
                                          weakController.wrappingUp = false;
                                        }]];
  } else {
    [c addAction:[UIAlertAction actionWithTitle:@"Wrap up"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
                                          weakController.wrappingUp = true;
                                        }]];
  }
  [reviewViewController presentViewController:c animated:YES completion:nil];
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
          finishedReviewItem:(ReviewItem *)reviewItem {
  [reviewViewController.localCachingClient sendProgress:@[reviewItem.answer]];
}

- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController {
  [reviewViewController performSegueWithIdentifier:@"reviewSummary" sender:reviewViewController];
}

@end
