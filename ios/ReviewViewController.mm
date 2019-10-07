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
#import "Tsurukame-Swift.h"
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
  TKMAskAgainLater,
};

static UILabel *CopyLabel(UILabel *original) {
  UILabel *copy = [[UILabel alloc] init];
  copy.hidden = original.hidden;
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
      switch (original.textAlignment) {
        case NSTextAlignmentNatural:
        case NSTextAlignmentLeft:
          copy.center = CGPointMake(CGRectGetMinX(original.frame) + copy.frame.size.width / 2,
                                    CGRectGetMinY(original.frame) + copy.frame.size.height / 2);
          break;
        default:
          copy.center = original.center;
          copy.bounds = original.bounds;
          break;
      };
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

@property(weak, nonatomic) IBOutlet UIButton *menuButton;
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

@property(weak, nonatomic) IBOutlet UILabel *wrapUpLabel;
@property(weak, nonatomic) IBOutlet UILabel *successRateLabel;
@property(weak, nonatomic) IBOutlet UILabel *doneLabel;
@property(weak, nonatomic) IBOutlet UILabel *queueLabel;
@property(weak, nonatomic) IBOutlet UIImageView *wrapUpIcon;
@property(weak, nonatomic) IBOutlet UIImageView *successRateIcon;
@property(weak, nonatomic) IBOutlet UIImageView *doneIcon;
@property(weak, nonatomic) IBOutlet UIImageView *queueIcon;

@property(nonatomic) IBOutlet NSLayoutConstraint *answerFieldToBottomConstraint;
@property(nonatomic) IBOutlet NSLayoutConstraint *answerFieldToSubjectDetailsViewConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *previousSubjectButtonWidthConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *previousSubjectButtonHeightConstraint;

@end

@implementation ReviewViewController {
  TKMKanaInput *_kanaInput;
  TKMServices *_services;
  BOOL _showMenuButton;
  BOOL _showSubjectHistory;
  __weak id<ReviewViewControllerDelegate> _delegate;

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

  BOOL _lastMarkAnswerWasFirstTime;

  CAGradientLayer *_previousSubjectGradient;

  UIImage *_tickImage;
  UIImage *_forwardArrowImage;

  TKMSubject *_previousSubject;
  UILabel *_previousSubjectLabel;

  UIImpactFeedbackGenerator *_hapticGenerator;

  // These are set to match the keyboard animation.
  CGFloat _animationDuration;
  UIViewAnimationCurve _animationCurve;

  NSString *_currentFontName;
  NSString *_normalFontName;
  CGFloat _defaultFontSize;
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
  }
  return self;
}

- (void)setupWithServices:(TKMServices *)services
                    items:(NSArray<ReviewItem *> *)items
           showMenuButton:(BOOL)showMenuButton
       showSubjectHistory:(BOOL)showSubjectHistory
                 delegate:(id<ReviewViewControllerDelegate>)delegate {
  _services = services;
  [self setItems:items];
  _showMenuButton = showMenuButton;
  _showSubjectHistory = showSubjectHistory;
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
    case ReviewOrder_BySRSStage:
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
    case ReviewOrder_LowestLevelFirst:
      [_reviewQueue sortUsingComparator:^NSComparisonResult(ReviewItem *a, ReviewItem *b) {
        if (a.assignment.level < b.assignment.level) return NSOrderedAscending;
        if (a.assignment.level > b.assignment.level) return NSOrderedDescending;
        if (a.assignment.subjectType < b.assignment.subjectType) return NSOrderedAscending;
        if (a.assignment.subjectType > b.assignment.subjectType) return NSOrderedDescending;
        return NSOrderedSame;
      }];
      break;
  }

  [self refillActiveQueue];
}

- (int)activeQueueLength {
  return (int)_activeQueue.count;
}

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  TKMAddShadowToView(_questionLabel, 1, 0.2, 4);
  TKMAddShadowToView(_previousSubjectButton, 0, 0.7, 4);

  _wrapUpIcon.image = [[UIImage imageNamed:@"baseline_access_time_black_24pt"]
      imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

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

  if (!_showMenuButton) {
    _menuButton.hidden = YES;
  }

  _normalFontName = kTKMJapaneseFontName;
  _currentFontName = _normalFontName;
  _defaultFontSize = _questionLabel.font.pointSize;

  UILongPressGestureRecognizer *longPressRecognizer =
      [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(didLongPressQuestionLabel:)];
  longPressRecognizer.minimumPressDuration = 0;
  longPressRecognizer.allowableMovement = 500;
  [_questionBackground addGestureRecognizer:longPressRecognizer];

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
  if (_subjectDetailsView.hidden) {
    [_answerField becomeFirstResponder];
    [_answerField reloadInputViews];
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_subjectDetailsView deselectLastSubjectChipTapped];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self focusAnswerField];
  });
}

- (void)focusAnswerField {
  [_answerField becomeFirstResponder];
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
  // When the review view is embedded in a lesson view controller, the review view doesn't extend
  // all the way to the bottom - the page selector view is below it.  Take this into account:
  // find out how far the bottom of our UIView is from the bottom of the window, and subtract that
  // distance from the constraint height.
  CGPoint viewBottomLeft = [self.view convertPoint:CGPointMake(0, CGRectGetMaxY(self.view.bounds))
                                            toView:self.view.window];
  CGFloat windowBottom = CGRectGetMaxY(self.view.window.bounds);
  CGFloat distanceFromViewBottomToWindowBottom = windowBottom - viewBottomLeft.y;

  _answerFieldToBottomConstraint.constant = height - distanceFromViewBottomToWindowBottom;

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

- (void)endReviewSession {
  [self performSegueWithIdentifier:@"reviewSummary" sender:self];
}

#pragma mark - Setup

- (void)refillActiveQueue {
  if (_wrappingUp) {
    return;
  }
  while (_activeQueue.count < _activeQueueSize && _reviewQueue.count != 0) {
    ReviewItem *item = [_reviewQueue firstObject];
    [_reviewQueue removeObjectAtIndex:0];
    [_activeQueue addObject:item];
  }
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
  NSString *wrapUpText = [NSString stringWithFormat:@"%d", (int)_activeQueue.count];

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
      taskTypePrompt =
          _activeTask.assignment.subjectType == TKMSubject_Type_Radical ? @"Name" : @"Meaning";
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

  // Choose a random font.
  _currentFontName = [self randomFontThatCanRenderText:_activeSubject.japanese];

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
  _kanaInput.alphabet =
      (_activeSubject.primaryReadings.firstObject.hasType &&
       _activeSubject.primaryReadings.firstObject.type == TKMReading_Type_Onyomi &&
       UserDefaults.useKatakanaForOnyomi)
          ? kTKMAlphabetKatakana
          : kTKMAlphabetHiragana;

  // We're changing the position of lots of labels at the same time as changing their contents.
  // To animate the contents change we have to do a UIView transition, which actually creates a new
  // view with the new contents, fades out the old one and fades in the new one, swapping them out
  // at the right time.  Unfortunately if we try to animate the view's position at the same time
  // only one of the copies gets animated, and the other one just fades out in place.
  // To work around this we copy and fade each view manually, but animate both copies.
  auto setupContextBlock = ^(AnimationContext *context) {
    if (![_questionLabel.attributedText isEqual:_activeSubject.japaneseText] ||
        ![_questionLabel.font.familyName isEqual:_currentFontName]) {
      context->AddFadingLabel(_questionLabel);
      _questionLabel.font = [UIFont fontWithName:_currentFontName
                                            size:[self questionLabelFontSize]];
      _questionLabel.attributedText = _activeSubject.japaneseText;
    }
    if (![_wrapUpLabel.text isEqual:wrapUpText]) {
      context->AddFadingLabel(_wrapUpLabel);
      _wrapUpLabel.text = wrapUpText;
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

#pragma mark - Random fonts

- (NSString *)randomFontThatCanRenderText:(NSString *)text {
  // Get the names of selected fonts.
  NSMutableArray<NSString *> *selectedFontNames = [NSMutableArray array];
  for (NSString *filename in UserDefaults.selectedFonts.allObjects) {
    [selectedFontNames addObject:[_services.fontLoader fontByName:filename].fontName];
  }

  // Pick a random one.
  while (selectedFontNames.count) {
    int fontIndex = arc4random_uniform((uint32_t)selectedFontNames.count);
    NSString *fontName = selectedFontNames[fontIndex];

    // If the font can't render the text, try another one.
    if (!TKMFontCanRenderText(fontName, text)) {
      [selectedFontNames removeObjectAtIndex:fontIndex];
      continue;
    }
    return fontName;
  }

  return _normalFontName;
}

#pragma mark - Animation

- (void)animateSubjectDetailsViewShown:(bool)shown
                     setupContextBlock:(void (^_Nullable)(AnimationContext *))setupContextBlock {
  bool cheats = [_delegate reviewViewControllerAllowsCheatsFor:_activeTask];

  if (shown) {
    _subjectDetailsView.hidden = NO;
    if (cheats) {
      _addSynonymButton.hidden = NO;
    }
  } else {
    if (_previousSubject) {
      _previousSubjectLabel.hidden = NO;
      _previousSubjectButton.hidden = NO;
    }
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
  CGFloat newButtonHeight =
      kPreviousSubjectButtonPadding * 2 + labelBounds.size.height * kPreviousSubjectScale;

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
        _previousSubjectButtonHeightConstraint.constant = newButtonHeight;
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

#pragma mark - Question label fonts

- (void)setCustomQuestionLabelFont:(BOOL)useCustomFont {
  NSString *fontName = useCustomFont ? _currentFontName : _normalFontName;
  _questionLabel.font = [UIFont fontWithName:fontName size:[self questionLabelFontSize]];
}

- (void)didLongPressQuestionLabel:(UILongPressGestureRecognizer *)gestureRecognizer {
  BOOL answered = !_subjectDetailsView.hidden;
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    [self setCustomQuestionLabelFont:answered];
  } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
    [self setCustomQuestionLabelFont:!answered];
  }
}

- (CGFloat)questionLabelFontSize {
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    return _defaultFontSize * 2.5;
  } else {
    return _defaultFontSize;
  }
}

#pragma mark - Menu button

- (IBAction)menuButtonPressed:(id)sender {
  [_delegate reviewViewController:self tappedMenuButton:_menuButton];
}

#pragma mark - Wrapping up

- (void)setWrappingUp:(bool)wrappingUp {
  _wrappingUp = wrappingUp;

  _wrapUpIcon.hidden = !wrappingUp;
  _wrapUpLabel.hidden = !wrappingUp;
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
  _answerField.text = [AnswerChecker normalizedString:_answerField.text
                                             taskType:_activeTaskType
                                             alphabet:_kanaInput.alphabet];
  AnswerCheckerResult result = [AnswerChecker checkAnswer:_answerField.text
                                                  subject:_activeSubject
                                           studyMaterials:_activeStudyMaterials
                                                 taskType:_activeTaskType
                                               dataLoader:_services.dataLoader];

  switch (result) {
    case AnswerCheckerResultPrecise:
    case AnswerCheckerResultImprecise: {
      [self markAnswer:TKMAnswerCorrect];
      break;
    }
    case AnswerCheckerResultIncorrect:
      [self markAnswer:TKMAnswerIncorrect];
      break;
    case AnswerCheckerResultOtherKanjiReading:
      [self shakeView:_answerField];
      break;
    case AnswerCheckerResultContainsInvalidCharacters:
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
  if (result == TKMAskAgainLater) {
    // Take the task out of the queue so it comes back later.
    [_activeQueue removeObjectAtIndex:_activeTaskIndex];
    [_activeTask reset];
    [_reviewQueue addObject:_activeTask];
    [self refillActiveQueue];
    [self randomTask];
    return;
  }

  const bool correct = result == TKMAnswerCorrect || result == TKMOverrideAnswerCorrect;

  if (correct) {
    [_hapticGenerator impactOccurred];
    [_hapticGenerator prepare];
  }

  // Mark the task.
  bool firstTimeAnswered = false;
  switch (_activeTaskType) {
    case kTKMTaskTypeMeaning:
      firstTimeAnswered = !_activeTask.answer.hasMeaningWrong;
      if (firstTimeAnswered ||
          (_lastMarkAnswerWasFirstTime && result == TKMOverrideAnswerCorrect)) {
        _activeTask.answer.meaningWrong = !correct;
      }
      _activeTask.answeredMeaning = correct;
      break;
    case kTKMTaskTypeReading:
      firstTimeAnswered = !_activeTask.answer.hasReadingWrong;
      if (firstTimeAnswered ||
          (_lastMarkAnswerWasFirstTime && result == TKMOverrideAnswerCorrect)) {
        _activeTask.answer.readingWrong = !correct;
      }
      _activeTask.answeredReading = correct;
      break;
    case kTKMTaskType_Max:
      abort();
  }
  _lastMarkAnswerWasFirstTime = firstTimeAnswered;

  // Update stats.
  switch (result) {
    case TKMAnswerCorrect:
      _tasksAnswered++;
      _tasksAnsweredCorrectly++;
      break;

    case TKMAnswerIncorrect:
      _tasksAnswered++;
      break;

    case TKMAskAgainLater:
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
    NSTimeInterval date = [NSDate date].timeIntervalSince1970;
    if (date > _activeTask.assignment.availableAt) {
      _activeTask.answer.createdAt = date;
    }

    [_services.localCachingClient sendProgress:@[ _activeTask.answer ]];

    _reviewsCompleted++;
    [_completedReviews addObject:_activeTask];
    [_activeQueue removeObjectAtIndex:_activeTaskIndex];
    [self refillActiveQueue];
  }

  // Show a new task if it was correct.
  if (result != TKMAnswerIncorrect) {
    if (UserDefaults.playAudioAutomatically && _activeTaskType == kTKMTaskTypeReading &&
        _activeSubject.hasVocabulary && _activeSubject.vocabulary.audioIdsArray_Count > 0) {
      [_services.audio playAudioForSubjectID:_activeSubject.id_p delegate:nil];
    }

    UILabel *previousSubjectLabel = nil;
    if (isSubjectFinished && _showSubjectHistory) {
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
  if (!UserDefaults.showAnswerImmediately && firstTimeAnswered) {
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

  auto setupContextBlock = ^(AnimationContext *context) {
    if (![_questionLabel.font.familyName isEqual:_normalFontName]) {
      context->AddFadingLabel(_questionLabel);
      _questionLabel.font = [UIFont fontWithName:_normalFontName size:[self questionLabelFontSize]];
    }
  };
  [self animateSubjectDetailsViewShown:true setupContextBlock:setupContextBlock];
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
                                          [unsafeSelf markCorrect];
                                        }
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Ask again later"
                                        style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        ReviewViewController *unsafeSelf = weakSelf;
                                        if (unsafeSelf) {
                                          [unsafeSelf askAgain];
                                        }
                                      }]];
  if (_activeTaskType == kTKMTaskTypeMeaning) {
    [c addAction:[UIAlertAction actionWithTitle:@"Add synonym"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_Nonnull action) {
                                          ReviewViewController *unsafeSelf = weakSelf;
                                          if (unsafeSelf) {
                                            [unsafeSelf addSynonym];
                                          }
                                        }]];
  }
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)markCorrect {
  [self markAnswer:TKMOverrideAnswerCorrect];
}

- (void)askAgain {
  [self markAnswer:TKMAskAgainLater];
}

- (void)addSynonym {
  if (!_activeStudyMaterials) {
    _activeStudyMaterials = [[TKMStudyMaterials alloc] init];
    _activeStudyMaterials.subjectId = _activeSubject.id_p;
    _activeStudyMaterials.subjectType = _activeSubject.subjectTypeString;
  }
  [_activeStudyMaterials.meaningSynonymsArray addObject:_answerField.text];
  [_services.localCachingClient updateStudyMaterial:_activeStudyMaterials];
  [self markAnswer:TKMOverrideAnswerCorrect];
}

// For no particularly apparent reason, this seemingly pointless implementation
// means that holding down the command key after (say) pressing ⌘C does not
// repeat the action continuously on all subsequent reviews
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  return [super canPerformAction:action withSender:sender];
}

#pragma mark - TKMSubjectDelegate

- (void)didTapSubject:(TKMSubject *)subject {
  [self performSegueWithIdentifier:@"subjectDetails" sender:subject];
}

#pragma mark - Keyboard navigation

- (BOOL)canBecomeFirstResponder {
  return true;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
  if (_subjectDetailsView.hidden) {
    return @[ [UIKeyCommand keyCommandWithInput:@"\t"
                                  modifierFlags:0
                                         action:@selector(toggleFont)
                           discoverabilityTitle:@"Toggle font"] ];
  }

  return @[
    [UIKeyCommand keyCommandWithInput:@"\r"
                        modifierFlags:0
                               action:@selector(enterKeyPressed)
                 discoverabilityTitle:@"Continue"],
    [UIKeyCommand keyCommandWithInput:@" "
                        modifierFlags:0
                               action:@selector(playAudio)
                 discoverabilityTitle:@"Play reading"],
    [UIKeyCommand keyCommandWithInput:@"a"
                        modifierFlags:UIKeyModifierCommand
                               action:@selector(askAgain)
                 discoverabilityTitle:@"Ask again later"],
    [UIKeyCommand keyCommandWithInput:@"c"
                        modifierFlags:UIKeyModifierCommand
                               action:@selector(markCorrect)
                 discoverabilityTitle:@"Mark correct"],
    [UIKeyCommand keyCommandWithInput:@"s"
                        modifierFlags:UIKeyModifierCommand
                               action:@selector(addSynonym)
                 discoverabilityTitle:@"Add as synonym"]
  ];
}

- (void)playAudio {
  if (!_subjectDetailsView.hidden) {
    [_subjectDetailsView playAudio];
  }
}

- (void)toggleFont {
  BOOL useCustomFont =
      [_questionLabel.font isEqual:TKMJapaneseFontLight(_questionLabel.font.pointSize)];
  [self setCustomQuestionLabelFont:useCustomFont];
}

@end
