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

#import "ReviewViewController.h"
#import "AnswerChecker.h"
#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "NSMutableArray+Shuffle.h"
#import "ReviewSummaryViewController.h"
#import "Style.h"
#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "SuccessAnimation.h"
#import "TKMAudio.h"
#import "TKMFontLoader.h"
#import "TKMGradientView.h"
#import "TKMKanaInput.h"
#import "TKMServices.h"
#import "Tables/TKMSubjectModelItem.h"
#import "UIView+SafeAreaInsets.h"
#import "UserDefaults.h"
#import "proto/Wanikani+Convenience.h"

#include <memory>
#include <vector>

static const NSTimeInterval kDefaultAnimationDuration = 0.25f;
// Undocumented, but it's what the keyboard animations use.
static const UIViewAnimationCurve kDefaultAnimationCurve = (UIViewAnimationCurve)7;

static const CGFloat kPreviousSubjectScale = 0.25f;
static const CGFloat kPreviousSubjectButtonPadding = 6.f;
static const CGFloat kPreviousSubjectAnimationDuration = 0.3f;

static NSArray<id> *kReadingGradient;
static NSArray<id> *kMeaningGradient;
static UIColor *kReadingTextColor;
static UIColor *kMeaningTextColor;
static UIColor *kDefaultButtonTintColor;

enum TKMAnswerResult {
  TKMAnswerCorrect,
  TKMAnswerIncorrect,
  TKMOverrideAnswerCorrect,
  TKMIgnoreAnswer,
};

static UILabel *CopyLabel(UILabel *original) {
  UILabel *copy = [[UILabel alloc] init];
  copy.transform = original.transform;
  copy.bounds = original.bounds;
  copy.center = original.center;
  copy.attributedText = original.attributedText;
  copy.font = original.font;
  copy.textColor = original.textColor;
  copy.textAlignment = original.textAlignment;
  [original.superview addSubview:copy];
  return copy;
}

class AnimationContext {
 public:
  AnimationContext(bool cheats, bool subjectDetailsViewShown)
      : cheats(cheats), subjectDetailsViewShown(subjectDetailsViewShown) {}

  bool cheats;
  bool subjectDetailsViewShown;

  void AddFadingLabel(UILabel *original) {
    UILabel *copy = CopyLabel(original);
    original.alpha = 0.f;
    fadingLabels.push_back(std::make_pair(original, copy));
  }

  void AnimateFadingLabels() {
    for (const auto &pair : fadingLabels) {
      UILabel *original = pair.first;
      UILabel *copy = pair.second;

      original.alpha = 1.f;
      copy.center = original.center;
      copy.bounds = original.bounds;
      copy.transform = original.transform;
      copy.alpha = 0.f;
    }
  }

  ~AnimationContext() {
    for (const auto &pair : fadingLabels) {
      UILabel *copy = pair.second;
      [copy removeFromSuperview];
    }
  }

 private:
  std::vector<std::pair<UILabel *, UILabel *>> fadingLabels;
};

@interface ReviewViewController () <UITextFieldDelegate, TKMSubjectDelegate>

@property(weak, nonatomic) IBOutlet UIButton *backButton;
@property(weak, nonatomic) IBOutlet TKMGradientView *questionBackground;
@property(weak, nonatomic) IBOutlet TKMGradientView *promptBackground;
@property(weak, nonatomic) IBOutlet UILabel *questionLabel;
@property(weak, nonatomic) IBOutlet UILabel *promptLabel;
@property(weak, nonatomic) IBOutlet UITextField *answerField;
@property(weak, nonatomic) IBOutlet UIButton *submitButton;
@property(weak, nonatomic) IBOutlet UIButton *addSynonymButton;
@property(weak, nonatomic) IBOutlet UIButton *revealAnswerButton;
@property(weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property(weak, nonatomic) IBOutlet TKMSubjectDetailsView *subjectDetailsView;
@property(weak, nonatomic) IBOutlet UIButton *previousSubjectButton;

@property(weak, nonatomic) IBOutlet UILabel *successRateLabel;
@property(weak, nonatomic) IBOutlet UILabel *doneLabel;
@property(weak, nonatomic) IBOutlet UILabel *queueLabel;
@property(weak, nonatomic) IBOutlet UIImageView *successRateIcon;
@property(weak, nonatomic) IBOutlet UIImageView *doneIcon;
@property(weak, nonatomic) IBOutlet UIImageView *queueIcon;

@property(nonatomic) IBOutlet NSLayoutConstraint *answerFieldToBottomConstraint;
@property(nonatomic) IBOutlet NSLayoutConstraint *answerFieldToSubjectDetailsViewConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *previousSubjectButtonWidthConstraint;

@end

@implementation ReviewViewController {
  TKMKanaInput *_kanaInput;
  TKMServices *_services;
  BOOL _hideBackButton;
  __weak id<ReviewViewControllerDelegate> _delegate;
  DefaultReviewViewControllerDelegate *_defaultDelegate;  // Required for the strong reference.

  NSMutableArray<ReviewItem *> *_activeQueue;
  NSMutableArray<ReviewItem *> *_reviewQueue;
  NSMutableArray<ReviewItem *> *_completedReviews;
  int _activeQueueSize;

  int _activeTaskIndex;  // An index into activeQueue;
  TKMTaskType _activeTaskType;
  ReviewItem *_activeTask;
  TKMSubject *_activeSubject;
  TKMStudyMaterials *_activeStudyMaterials;

  int _tasksAnsweredCorrectly;
  int _tasksAnswered;

  CAGradientLayer *_previousSubjectGradient;

  UIImage *_tickImage;
  UIImage *_forwardArrowImage;

  TKMSubject *_previousSubject;
  UILabel *_previousSubjectLabel;

  UIImpactFeedbackGenerator *_hapticGenerator;

  // These are set to match the keyboard animation.
  CGFloat _animationDuration;
  UIViewAnimationCurve _animationCurve;

  NSString *_usedFontName;
  NSString *_normalFontName;
}

#pragma mark - Constructors

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kReadingGradient = @[
      (id)[UIColor colorWithRed:0.235f green:0.235f blue:0.235f alpha:1.0f].CGColor,
      (id)[UIColor colorWithRed:0.102f green:0.102f blue:0.102f alpha:1.0f].CGColor
    ];
    kMeaningGradient = @[
      (id)[UIColor colorWithRed:0.933f green:0.933f blue:0.933f alpha:1.0f].CGColor,
      (id)[UIColor colorWithRed:0.882f green:0.882f blue:0.882f alpha:1.0f].CGColor
    ];
    kReadingTextColor = [UIColor whiteColor];
    kMeaningTextColor = [UIColor colorWithRed:0.333f green:0.333f blue:0.333f alpha:1.0f];
    kDefaultButtonTintColor = [[[UIButton alloc] init] tintColor];
  });

  self = [super initWithCoder:aDecoder];
  if (self) {
    _kanaInput = [[TKMKanaInput alloc] initWithDelegate:self];
    _hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

    _tickImage = [UIImage imageNamed:@"confirm"];
    _forwardArrowImage = [UIImage imageNamed:@"ic_arrow_forward_white"];

    _animationDuration = kDefaultAnimationDuration;
    _animationCurve = kDefaultAnimationCurve;

    UIKeyCommand *enterCommand = [UIKeyCommand keyCommandWithInput:@"\r"
                                                     modifierFlags:0
                                                            action:@selector(enterKeyPressed)];
    [self addKeyCommand:enterCommand];
  }
  return self;
}

- (void)setupWithServices:(TKMServices *)services
                    items:(NSArray<ReviewItem *> *)items
           hideBackButton:(BOOL)hideBackButton
                 delegate:(nullable id<ReviewViewControllerDelegate>)delegate {
  if (!delegate) {
    _defaultDelegate = [[DefaultReviewViewControllerDelegate alloc] initWithServices:services];
    delegate = _defaultDelegate;
  }

  _services = services;
  [self setItems:items];
  _hideBackButton = hideBackButton;
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
  TKMAddShadowToView(_questionLabel, 1, 0.2, 4);
  TKMAddShadowToView(_previousSubjectButton, 0, 0.7, 4);

  _previousSubjectGradient = [CAGradientLayer layer];
  _previousSubjectGradient.cornerRadius = 4.f;
  [_previousSubjectButton.layer addSublayer:_previousSubjectGradient];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(keyboardWillShow:)
             name:UIKeyboardWillShowNotification
           object:nil];

  [_subjectDetailsView setupWithServices:_services showHints:NO subjectDelegate:self];

  _answerField.delegate = _kanaInput;
  [_answerField addTarget:self
                   action:@selector(answerFieldValueDidChange)
         forControlEvents:UIControlEventEditingChanged];

  if (_hideBackButton) {
    _backButton.hidden = YES;
  }

  _usedFontName = _questionLabel.font.fontName;
  _normalFontName = _questionLabel.font.fontName;

  [self viewDidLayoutSubviews];
  [self randomTask];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  // Fix the extra inset at the top of the subject details view.
  _subjectDetailsView.contentInset = UIEdgeInsetsMake(-self.view.tkm_safeAreaInsets.top, 0, 0, 0);
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_subjectDetailsView deselectLastSubjectChipTapped];
  dispatch_async(dispatch_get_main_queue(), ^{
    [_answerField becomeFirstResponder];
  });
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

#pragma mark - Event handlers

- (void)keyboardWillShow:(NSNotification *)notification {
  CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGFloat keyboardHeight = keyboardFrame.size.height;
  _animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  _animationCurve = (UIViewAnimationCurve)
      [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];

  [self resizeKeyboardToHeight:keyboardHeight];
}

- (void)resizeKeyboardToHeight:(CGFloat)height {
  _answerFieldToBottomConstraint.constant = height;

  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:_animationDuration];
  [UIView setAnimationCurve:_animationCurve];
  [UIView setAnimationBeginsFromCurrentState:YES];

  [self.view layoutIfNeeded];

  [UIView commitAnimations];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"reviewSummary"]) {
    ReviewSummaryViewController *vc =
        (ReviewSummaryViewController *)segue.destinationViewController;
    [vc setupWithServices:_services items:_completedReviews];
  } else if ([segue.identifier isEqualToString:@"subjectDetails"]) {
    SubjectDetailsViewController *vc =
        (SubjectDetailsViewController *)segue.destinationViewController;
    [vc setupWithServices:_services subject:(TKMSubject *)sender];
  }
}

#pragma mark - Setup

- (void)refillActiveQueue {
  if (_wrappingUp) {
    [self updateWrapUpButton];
    return;
  }
  while (_activeQueue.count < _activeQueueSize && _reviewQueue.count != 0) {
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
    successRateText = [NSString
        stringWithFormat:@"%d%%", (int)((double)(_tasksAnsweredCorrectly) / _tasksAnswered * 100)];
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
  _activeSubject = [_services.dataLoader loadSubject:_activeTask.assignment.subjectId];
  _activeStudyMaterials =
      [_services.localCachingClient getStudyMaterialForID:_activeTask.assignment.subjectId];

  // Choose whether to ask the meaning or the reading.
  if (_activeTask.answeredMeaning) {
    _activeTaskType = kTKMTaskTypeReading;
  } else if (_activeTask.answeredReading || _activeSubject.hasRadical) {
    _activeTaskType = kTKMTaskTypeMeaning;
  } else if (UserDefaults.groupMeaningReading) {
    _activeTaskType = UserDefaults.meaningFirst ? kTKMTaskTypeMeaning : kTKMTaskTypeReading;
  } else {
    _activeTaskType = (TKMTaskType)arc4random_uniform(kTKMTaskType_Max);
  }

  // Fill the question labels.
  NSString *subjectTypePrompt;
  NSString *taskTypePrompt;
  NSArray *promptGradient;
  UIColor *promptTextColor;
  NSString *taskTypePlaceholder;

  switch (_activeTask.assignment.subjectType) {
    case TKMSubject_Type_Kanji:
      subjectTypePrompt = @"Kanji";
      break;
    case TKMSubject_Type_Radical:
      subjectTypePrompt = @"Radical";
      break;
    case TKMSubject_Type_Vocabulary:
      subjectTypePrompt = @"Vocabulary";
      break;
  }
  switch (_activeTaskType) {
    case kTKMTaskTypeMeaning:
      _kanaInput.enabled = false;
      taskTypePrompt = @"Meaning";
      promptGradient = kMeaningGradient;
      promptTextColor = kMeaningTextColor;
      taskTypePlaceholder = @"Your Response";
      break;
    case kTKMTaskTypeReading:
      _kanaInput.enabled = true;
      taskTypePrompt = @"Reading";
      promptGradient = kReadingGradient;
      promptTextColor = kReadingTextColor;
      taskTypePlaceholder = @"答え";
      break;
    case kTKMTaskType_Max:
      assert(false);
  }

  // Set random font
  if (UserDefaults.randomFontsEnabled) {
    TKMFont *randomFont = [TKMFontLoader getRandomFontToRender:_activeSubject.japaneseText.string];
    _usedFontName = randomFont.fontName;
  }

  UIFont *boldFont = [UIFont boldSystemFontOfSize:self.promptLabel.font.pointSize];
  NSMutableAttributedString *prompt = [[NSMutableAttributedString alloc]
      initWithString:[NSString stringWithFormat:@"%@ %@", subjectTypePrompt, taskTypePrompt]];
  [prompt setAttributes:@{NSFontAttributeName : boldFont}
                  range:NSMakeRange(prompt.length - taskTypePrompt.length, taskTypePrompt.length)];

  // Text color.
  _promptLabel.textColor = promptTextColor;

  // Submit button.
  _submitButton.enabled = false;

  // Background gradients.
  [_questionBackground animateColorsTo:TKMGradientForAssignment(_activeTask.assignment)
                              duration:_animationDuration];
  [_promptBackground animateColorsTo:promptGradient duration:_animationDuration];

  // Accessibility.
  _successRateLabel.accessibilityLabel =
      [NSString stringWithFormat:@"%@ correct so far", successRateText];
  _doneLabel.accessibilityLabel = [NSString stringWithFormat:@"%@ done", doneText];
  _queueLabel.accessibilityLabel = [NSString stringWithFormat:@"%@ remaining", queueText];
  _questionLabel.accessibilityLabel =
      [NSString stringWithFormat:@"Japanese %@. Question", subjectTypePrompt];

  _answerField.text = nil;
  _answerField.placeholder = taskTypePlaceholder;

  // We're changing the position of lots of labels at the same time as changing their contents.
  // To animate the contents change we have to do a UIView transition, which actually creates a new
  // view with the new contents, fades out the old one and fades in the new one, swapping them out
  // at the right time.  Unfortunately if we try to animate the view's position at the same time
  // only one of the copies gets animated, and the other one just fades out in place.
  // To work around this we copy and fade each view manually, but animate both copies.
  auto setupContextBlock = ^(AnimationContext *context) {
    if (![_questionLabel.attributedText isEqual:_activeSubject.japaneseText]) {
      context->AddFadingLabel(_questionLabel);
      _questionLabel.attributedText = _activeSubject.japaneseText;
    }
    if (![_successRateLabel.text isEqual:successRateText]) {
      context->AddFadingLabel(_successRateLabel);
      _successRateLabel.text = successRateText;
    }
    if (![_doneLabel.text isEqual:doneText]) {
      context->AddFadingLabel(_doneLabel);
      _doneLabel.text = doneText;
    }
    if (![_queueLabel.text isEqual:queueText]) {
      context->AddFadingLabel(_queueLabel);
      _queueLabel.text = queueText;
    }
    if (![_promptLabel.attributedText.string isEqual:prompt.string]) {
      context->AddFadingLabel(_promptLabel);
      _promptLabel.attributedText = prompt;
    }
  };

  [self animateSubjectDetailsViewShown:false setupContextBlock:setupContextBlock];
}

#pragma mark - Animation

- (void)animateSubjectDetailsViewShown:(bool)shown
                     setupContextBlock:(void (^_Nullable)(AnimationContext *))setupContextBlock {
  bool cheats = [_delegate reviewViewController:self allowsCheatsFor:_activeTask];

  if (shown) {
    _subjectDetailsView.hidden = NO;
    if (cheats) {
      _addSynonymButton.hidden = NO;
    }
  } else {
    _previousSubjectLabel.hidden = NO;
    _previousSubjectButton.hidden = NO;
  }

  // Change the submit button icon.
  UIImage *submitButtonImage = shown ? _forwardArrowImage : _tickImage;
  [_submitButton setImage:submitButtonImage forState:UIControlStateNormal];

  // We have to do the UIView animation this way (rather than using the block syntax) so we can set
  // UIViewAnimationCurve.  Create a context to pass to the stop selector.
  AnimationContext *context = new AnimationContext(cheats, shown);
  if (setupContextBlock) {
    setupContextBlock(context);
  }

  [UIView beginAnimations:nil context:context];
  [UIView setAnimationDelegate:self];
  [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
  [UIView setAnimationDuration:_animationDuration];
  [UIView setAnimationCurve:_animationCurve];
  [UIView setAnimationBeginsFromCurrentState:NO];

  // Constraints.
  _answerFieldToBottomConstraint.active = !shown;

  // Enable/disable the answer field, and set its first responder status.
  // This makes the keyboard appear or disappear immediately.  We need this animation to happen
  // here so it's in sync with the others.
  _answerField.enabled = !shown;
  if (!shown) {
    [_answerField becomeFirstResponder];
  } else {
    [_answerField resignFirstResponder];
  }

  // Scale the text in the question label.
  const float scale = shown ? 0.7 : 1.0;
  _questionLabel.transform = CGAffineTransformMakeScale(scale, scale);

  [self.view layoutIfNeeded];

  context->AnimateFadingLabels();

  // Fade the controls.
  _subjectDetailsView.alpha = shown ? 1.0 : 0.0;
  if (cheats) {
    _addSynonymButton.alpha = shown ? 1.0 : 0.0;
  }
  _revealAnswerButton.alpha = 0.0;
  _previousSubjectLabel.alpha = shown ? 0.0 : 1.0;
  _previousSubjectButton.alpha = shown ? 0.0 : 1.0;

  // Change the background color of the answer field.
  _answerField.textColor = shown ? [UIColor redColor] : [UIColor blackColor];

  // Scroll to the top.
  [_subjectDetailsView setContentOffset:CGPointMake(0, -_subjectDetailsView.contentInset.top)];

  [UIView commitAnimations];
}

- (void)animationDidStop:(NSString *)animationID
                finished:(NSNumber *)finished
                 context:(void *)contextPtr {
  std::unique_ptr<AnimationContext> context(reinterpret_cast<AnimationContext *>(contextPtr));

  _revealAnswerButton.hidden = YES;
  if (context->subjectDetailsViewShown) {
    _previousSubjectLabel.hidden = YES;
    _previousSubjectButton.hidden = YES;
  } else {
    _subjectDetailsView.hidden = YES;
    if (context->cheats) {
      _addSynonymButton.hidden = YES;
    }
  }
}

#pragma mark - Previous subject button

- (void)animateLabelToPreviousSubjectButton:(UILabel *)label {
  CGPoint oldLabelCenter = label.center;
  CGRect labelBounds;
  labelBounds.origin = CGPointZero;
  labelBounds.size = [label sizeThatFits:CGSizeMake(0, 0)];
  label.bounds = labelBounds;
  label.center = oldLabelCenter;

  CGFloat newButtonWidth =
      kPreviousSubjectButtonPadding * 2 + labelBounds.size.width * kPreviousSubjectScale;

  NSArray<id> *newGradient = TKMGradientForSubject(_previousSubject);

  [self.view layoutIfNeeded];
  [UIView animateWithDuration:kPreviousSubjectAnimationDuration
      delay:0.f
      options:UIViewAnimationOptionCurveEaseOut
      animations:^{
        label.transform = CGAffineTransformMakeScale(kPreviousSubjectScale, kPreviousSubjectScale);

        label.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutConstraint *centerYConstraint =
            [NSLayoutConstraint constraintWithItem:label
                                         attribute:NSLayoutAttributeCenterY
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:_previousSubjectButton
                                         attribute:NSLayoutAttributeCenterY
                                        multiplier:1.f
                                          constant:0];
        NSLayoutConstraint *centerXConstraint =
            [NSLayoutConstraint constraintWithItem:label
                                         attribute:NSLayoutAttributeCenterX
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:_previousSubjectButton
                                         attribute:NSLayoutAttributeCenterX
                                        multiplier:1.f
                                          constant:0];
        [self.view addConstraints:@[ centerXConstraint, centerYConstraint ]];

        _previousSubjectButtonWidthConstraint.constant = newButtonWidth;
        [self.view layoutIfNeeded];

        _previousSubjectGradient.colors = newGradient;
        _previousSubjectGradient.frame = _previousSubjectButton.bounds;
        _previousSubjectButton.alpha = 1.f;

        _previousSubjectLabel.transform = CGAffineTransformMakeScale(0.01, 0.01);
        _previousSubjectLabel.alpha = 0.01;
      }
      completion:^(BOOL finished) {
        [_previousSubjectLabel removeFromSuperview];
        _previousSubjectLabel = label;
      }];
}

- (IBAction)previousSubjectButtonPressed:(id)sender {
  [self performSegueWithIdentifier:@"subjectDetails" sender:_previousSubject];
}

#pragma mark - Question Label Tapped

- (IBAction)questionLabelTapped:(id)sender {
  if (!UserDefaults.randomFontsEnabled) {
    return;
  }
  CGFloat size = [_questionLabel.font pointSize];
  NSString *newFontName = [_questionLabel.font.fontName isEqualToString:_normalFontName]
                              ? _usedFontName
                              : _normalFontName;
  [_questionLabel setFont:[UIFont fontWithName:newFontName size:size]];
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [self enterKeyPressed];
  return YES;
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

- (void)submit {
  NSString *answer = [_answerField.text copy];
  TKMAnswerCheckerResult result = CheckAnswer(&answer, _activeSubject, _activeStudyMaterials,
                                              _activeTaskType, _services.dataLoader);
  _answerField.text = answer;

  switch (result) {
    case kTKMAnswerPrecise:
    case kTKMAnswerImprecise: {
      [self markAnswer:TKMAnswerCorrect];
      break;
    }
    case kTKMAnswerIncorrect:
      [self markAnswer:TKMAnswerIncorrect];
      break;
    case kTKMAnswerOtherKanjiReading:
      [self shakeView:_answerField];
      break;
    case kTKMAnswerContainsInvalidCharacters:
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

- (void)markAnswer:(TKMAnswerResult)result {
  const bool correct = result == TKMAnswerCorrect || result == TKMOverrideAnswerCorrect;

  if (correct) {
    [_hapticGenerator impactOccurred];
    [_hapticGenerator prepare];
  }

  // Mark the task.
  bool firstTimeWrong = false;
  switch (_activeTaskType) {
    case kTKMTaskTypeMeaning:
      if (result == TKMIgnoreAnswer) {
        _activeTask.answer.meaningWrong = false;
        _activeTask.answer.hasMeaningWrong = false;
      } else {
        firstTimeWrong = !_activeTask.answer.hasMeaningWrong;
        if (firstTimeWrong || result == TKMOverrideAnswerCorrect) {
          _activeTask.answer.meaningWrong = !correct;
        }
      }
      _activeTask.answeredMeaning = correct;
      break;
    case kTKMTaskTypeReading:
      if (result == TKMIgnoreAnswer) {
        _activeTask.answer.readingWrong = false;
        _activeTask.answer.hasReadingWrong = false;
      } else {
        firstTimeWrong = !_activeTask.answer.hasReadingWrong;
        if (firstTimeWrong || result == TKMOverrideAnswerCorrect) {
          _activeTask.answer.readingWrong = !correct;
        }
      }
      _activeTask.answeredReading = correct;
      break;
    case kTKMTaskType_Max:
      abort();
  }

  // Update stats.
  switch (result) {
    case TKMAnswerCorrect:
      _tasksAnswered++;
      _tasksAnsweredCorrectly++;
      break;

    case TKMAnswerIncorrect:
      _tasksAnswered++;
      break;

    case TKMIgnoreAnswer:
      _tasksAnswered--;
      break;

    case TKMOverrideAnswerCorrect:
      _tasksAnsweredCorrectly++;
      break;
  }

  // Remove it from the active queue if that was the last part.
  bool isSubjectFinished =
      _activeTask.answeredMeaning && (_activeSubject.hasRadical || _activeTask.answeredReading);
  bool didLevelUp = (!_activeTask.answer.readingWrong && !_activeTask.answer.meaningWrong);
  int newSrsStage =
      didLevelUp ? _activeTask.assignment.srsStage + 1 : _activeTask.assignment.srsStage - 1;
  if (isSubjectFinished) {
    [_delegate reviewViewController:self finishedReviewItem:_activeTask];

    _reviewsCompleted++;
    [_completedReviews addObject:_activeTask];
    [_activeQueue removeObjectAtIndex:_activeTaskIndex];
    [self refillActiveQueue];
  }

  // Show a new task if it was correct.
  if (result != TKMAnswerIncorrect) {
    if (UserDefaults.playAudioAutomatically && _activeTaskType == kTKMTaskTypeReading &&
        _activeSubject.hasVocabulary && _activeSubject.vocabulary.hasAudioFile) {
      [_services.audio playAudioForSubjectID:_activeSubject.id_p delegate:nil];
    }

    UILabel *previousSubjectLabel = nil;
    if (isSubjectFinished && [_delegate reviewViewControllerShowsSubjectHistory:self]) {
      previousSubjectLabel = CopyLabel(_questionLabel);
      _previousSubject = _activeSubject;
    }
    [self randomTask];
    if (correct) {
      RunSuccessAnimation(_answerField, _doneLabel, isSubjectFinished, didLevelUp, newSrsStage);
    }
    if (previousSubjectLabel != nil) {
      [self animateLabelToPreviousSubjectButton:previousSubjectLabel];
    }
    return;
  }

  // Otherwise show the correct answer.
  if (!UserDefaults.showAnswerImmediately && firstTimeWrong) {
    _revealAnswerButton.hidden = NO;
    [UIView animateWithDuration:_animationDuration
                     animations:^{
                       _answerField.textColor = [UIColor redColor];
                       _answerField.enabled = NO;
                       _revealAnswerButton.alpha = 1.0;
                       [_submitButton setImage:_forwardArrowImage forState:UIControlStateNormal];
                     }];
  } else {
    [self revealAnswerButtonPressed:nil];
  }
}

- (IBAction)revealAnswerButtonPressed:(id)sender {
  [_subjectDetailsView updateWithSubject:_activeSubject studyMaterials:_activeStudyMaterials];

  [self animateSubjectDetailsViewShown:true setupContextBlock:nil];
}

#pragma mark - Ignoring incorrect answers

- (IBAction)addSynonymButtonPressed:(id)sender {
  __weak ReviewViewController *weakSelf = self;

  UIAlertController *c =
      [UIAlertController alertControllerWithTitle:@"Ignore incorrect answer?"
                                          message:
                                              @"Don't cheat!  Only use this if you promise you "
                                               "knew the correct answer."
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  c.popoverPresentationController.sourceView = _addSynonymButton;
  c.popoverPresentationController.sourceRect = _addSynonymButton.bounds;

  [c addAction:[UIAlertAction actionWithTitle:@"My answer was correct"
                                        style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        ReviewViewController *unsafeSelf = weakSelf;
                                        if (unsafeSelf) {
                                          [unsafeSelf markAnswer:TKMOverrideAnswerCorrect];
                                        }
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Ask again later"
                                        style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        ReviewViewController *unsafeSelf = weakSelf;
                                        if (unsafeSelf) {
                                          [unsafeSelf markAnswer:TKMIgnoreAnswer];
                                        }
                                      }]];
  if (_activeTaskType == kTKMTaskTypeMeaning) {
    [c addAction:[UIAlertAction actionWithTitle:@"Add synonym"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_Nonnull action) {
                                          ReviewViewController *unsafeSelf = weakSelf;
                                          if (unsafeSelf) {
                                            [unsafeSelf addSynonym];
                                            [unsafeSelf markAnswer:TKMOverrideAnswerCorrect];
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
    _activeStudyMaterials = [[TKMStudyMaterials alloc] init];
    _activeStudyMaterials.subjectId = _activeSubject.id_p;
    _activeStudyMaterials.subjectType = _activeSubject.subjectTypeString;
  }
  [_activeStudyMaterials.meaningSynonymsArray addObject:_answerField.text];
  [_services.localCachingClient updateStudyMaterial:_activeStudyMaterials];
}

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  [self performSegueWithIdentifier:@"subjectDetails" sender:subject];
}

@end

@implementation DefaultReviewViewControllerDelegate {
  TKMServices *_services;
}

- (instancetype)initWithServices:(TKMServices *)services {
  self = [super init];
  if (self) {
    _services = services;
  }
  return self;
}

- (bool)reviewViewController:(ReviewViewController *)reviewViewController
             allowsCheatsFor:(ReviewItem *)reviewItem {
  return UserDefaults.enableCheats;
}

- (bool)reviewViewControllerShowsSubjectHistory:(ReviewViewController *)reviewViewController {
  return true;
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
            tappedBackButton:(UIButton *)backButton {
  if (reviewViewController.tasksAnsweredCorrectly == 0) {
    [reviewViewController.navigationController popToRootViewControllerAnimated:YES];
    return;
  }

  __weak ReviewViewController *weakController = reviewViewController;
  UIAlertController *c = [UIAlertController
      alertControllerWithTitle:@"End review session?"
                       message:@"You'll lose progress on any half-answered reviews"
                preferredStyle:UIAlertControllerStyleActionSheet];
  c.popoverPresentationController.sourceView = backButton;
  c.popoverPresentationController.sourceRect = backButton.bounds;

  [c addAction:[UIAlertAction actionWithTitle:@"End review session"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        [weakController performSegueWithIdentifier:@"reviewSummary"
                                                                            sender:weakController];
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  if (reviewViewController.wrappingUp) {
    [c addAction:[UIAlertAction actionWithTitle:@"Cancel wrap up"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_Nonnull action) {
                                          weakController.wrappingUp = false;
                                        }]];
  } else {
    [c addAction:[UIAlertAction actionWithTitle:@"Wrap up"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_Nonnull action) {
                                          weakController.wrappingUp = true;
                                        }]];
  }
  [reviewViewController presentViewController:c animated:YES completion:nil];
}

- (void)reviewViewController:(ReviewViewController *)reviewViewController
          finishedReviewItem:(ReviewItem *)reviewItem {
  [_services.localCachingClient sendProgress:@[ reviewItem.answer ]];
}

- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController {
  [reviewViewController performSegueWithIdentifier:@"reviewSummary" sender:reviewViewController];
}

@end
