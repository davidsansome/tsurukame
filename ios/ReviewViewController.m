#import "AnswerChecker.h"
#import "LanguageSpecificTextField.h"
#import "ReviewViewController.h"
#import "SubjectDetailsRenderer.h"
#import "WKKanaInput.h"
#import "proto/Wanikani+Convenience.h"

#import <WebKit/WebKit.h>

static const int kActiveQueueSize = 10;

static NSArray<id> *kRadicalGradient;
static NSArray<id> *kKanjiGradient;
static NSArray<id> *kVocabularyGradient;
static NSArray<id> *kReadingGradient;
static NSArray<id> *kMeaningGradient;
static UIColor *kReadingTextColor;
static UIColor *kMeaningTextColor;

static void AddShadowToView(UIView *view) {
  view.layer.shadowColor = [UIColor blackColor].CGColor;
  view.layer.shadowOffset = CGSizeMake(1, 1);
  view.layer.shadowOpacity = 0.6;
  view.layer.shadowRadius = 1.5;
  view.clipsToBounds = NO;
}

@interface ReviewViewController () <UITextFieldDelegate, WKNavigationDelegate>

@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIView *questionBackground;
@property (weak, nonatomic) IBOutlet UIView *promptBackground;
@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UILabel *promptLabel;
@property (weak, nonatomic) IBOutlet LanguageSpecificTextField *answerField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet WKWebView *subjectDetailsView;

@property (weak, nonatomic) IBOutlet UILabel *successRateLabel;
@property (weak, nonatomic) IBOutlet UILabel *doneLabel;
@property (weak, nonatomic) IBOutlet UILabel *queueLabel;
@property (weak, nonatomic) IBOutlet UIImageView *successRateIcon;
@property (weak, nonatomic) IBOutlet UIImageView *doneIcon;
@property (weak, nonatomic) IBOutlet UIImageView *queueIcon;

@end

@implementation ReviewViewController {
  WKSubjectDetailsRenderer *_subjectDetailsRenderer;
  WKKanaInput *_kanaInput;

  NSMutableArray<ReviewItem *> *_activeQueue;
  NSMutableArray<ReviewItem *> *_reviewQueue;
  bool _wrapUp;

  int _activeTaskIndex;  // An index into activeQueue;
  WKTaskType _activeTaskType;
  ReviewItem *_activeTask;
  WKSubject *_activeSubject;
  WKStudyMaterials *_activeStudyMaterials;

  int _reviewsCompleted;
  int _tasksAnsweredCorrectly;
  int _tasksAnswered;

  CAGradientLayer *_questionGradient;
  CAGradientLayer *_promptGradient;
}

#pragma mark - Constructors

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kRadicalGradient = @[(id)[UIColor colorWithRed:0.000f green:0.667f blue:1.000f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.000f green:0.576f blue:0.867f alpha:1.0f].CGColor];
    kKanjiGradient = @[(id)[UIColor colorWithRed:1.000f green:0.000f blue:0.667f alpha:1.0f].CGColor,
                       (id)[UIColor colorWithRed:0.867f green:0.000f blue:0.576f alpha:1.0f].CGColor];
    kVocabularyGradient = @[(id)[UIColor colorWithRed:0.667f green:0.000f blue:1.000f alpha:1.0f].CGColor,
                            (id)[UIColor colorWithRed:0.576f green:0.000f blue:0.867f alpha:1.0f].CGColor];
    kReadingGradient = @[(id)[UIColor colorWithRed:0.235f green:0.235f blue:0.235f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.102f green:0.102f blue:0.102f alpha:1.0f].CGColor];
    kMeaningGradient = @[(id)[UIColor colorWithRed:0.933f green:0.933f blue:0.933f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.882f green:0.882f blue:0.882f alpha:1.0f].CGColor];
    kReadingTextColor = [UIColor whiteColor];
    kMeaningTextColor = [UIColor colorWithRed:0.333f green:0.333f blue:0.333f alpha:1.0f];
  });
  
  self = [super initWithCoder:aDecoder];
  if (self) {
    _kanaInput = [[WKKanaInput alloc] initWithDelegate:self];
  }
  return self;
}

- (void)setDataLoader:(DataLoader *)dataLoader {
  _dataLoader = dataLoader;
  _subjectDetailsRenderer = [[WKSubjectDetailsRenderer alloc] initWithDataLoader:_dataLoader];
}

- (void)startReviewWithItems:(NSArray<ReviewItem *> *)items {
  NSLog(@"Starting review with %lu items", (unsigned long)items.count);
  _reviewQueue = [NSMutableArray arrayWithArray:items];
  _activeQueue = [NSMutableArray array];
  
  [self refillActiveQueue];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  AddShadowToView(_successRateIcon);
  AddShadowToView(_successRateLabel);
  AddShadowToView(_doneIcon);
  AddShadowToView(_doneLabel);
  AddShadowToView(_queueIcon);
  AddShadowToView(_queueLabel);
  
  _questionGradient = [CAGradientLayer layer];
  [_questionBackground.layer addSublayer:_questionGradient];
  _promptGradient = [CAGradientLayer layer];
  [_promptBackground.layer addSublayer:_promptGradient];
  
  _subjectDetailsView.navigationDelegate = self;
  
  _answerField.delegate = _kanaInput;
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  _questionGradient.frame = _questionBackground.bounds;
  _promptGradient.frame = _promptBackground.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
  [self randomTask];
  [super viewWillAppear:animated];
  [_answerField becomeFirstResponder];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

- (IBAction)backButtonPressed:(id)sender {
  __weak ReviewViewController *weakSelf = self;
  
  UIAlertController *c =
      [UIAlertController alertControllerWithTitle:@"End review session?"
                                          message:@"You'll lose progress on any half-answered reviews"
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  [c addAction:[UIAlertAction actionWithTitle:@"End review session"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction * _Nonnull action) {
                                          [self.navigationController popViewControllerAnimated:YES];
                                        }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  if (_wrapUp) {
    [c addAction:[UIAlertAction actionWithTitle:@"Cancel wrap up"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
                                          ReviewViewController *self = weakSelf;
                                          if (self) {
                                            self->_wrapUp = false;
                                            [self updateWrapUpButton];
                                          }
                                        }]];
  } else {
    [c addAction:[UIAlertAction actionWithTitle:@"Wrap up"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
                                          ReviewViewController *self = weakSelf;
                                          if (self) {
                                            self->_wrapUp = true;
                                            [self updateWrapUpButton];
                                          }
                                        }]];
  }
  [self presentViewController:c animated:YES completion:nil];
}

#pragma mark - Setup

- (void)refillActiveQueue {
  if (_wrapUp) {
    return;
  }
  while (_activeQueue.count < kActiveQueueSize &&
         _reviewQueue.count != 0) {
    const NSUInteger i = arc4random_uniform((uint32_t)_reviewQueue.count);
    ReviewItem * item = [_reviewQueue objectAtIndex:i];
    [_reviewQueue removeObjectAtIndex:i];
    [_activeQueue addObject:item];
  }
}

- (void)updateWrapUpButton {
  NSString *title;
  if (_wrapUp) {
    title = [NSString stringWithFormat:@"Back (%lu)", (unsigned long)_activeQueue.count];
  } else {
    title = @"Back";
  }
  [_backButton setTitle:title forState:UIControlStateNormal];
}

- (void)randomTask {
  // Update the progress labels.
  if (_tasksAnswered == 0) {
    self.successRateLabel.text = @"100%";
  } else {
    self.successRateLabel.text = [NSString stringWithFormat:@"%d%%",
                                  (int)((double)(_tasksAnsweredCorrectly) / _tasksAnswered * 100)];
  }
  int queueLength = (int)(_activeQueue.count + _reviewQueue.count);
  self.doneLabel.text = [NSString stringWithFormat:@"%d", _reviewsCompleted];
  self.queueLabel.text = [NSString stringWithFormat:@"%d", queueLength];
  
  // Update the progress bar.
  int totalLength = queueLength + _reviewsCompleted;
  if (totalLength == 0) {
    self.progressBar.progress = 0.0;
  } else {
    self.progressBar.progress = (double)(_reviewsCompleted) / totalLength;
  }
  
  // Hide the answer from last time.
  _answerField.text = nil;
  _answerField.enabled = YES;
  _subjectDetailsView.hidden = YES;
  
  // Choose a random task from the active queue.
  if (_activeQueue.count == 0) {
    return;
  }
  _activeTaskIndex = arc4random_uniform((uint32_t)_activeQueue.count);
  _activeTask = _activeQueue[_activeTaskIndex];
  _activeSubject = [_dataLoader loadSubject:_activeTask.assignment.subjectId];
  _activeStudyMaterials = nil;
  
  [_localCachingClient getStudyMaterialForID:_activeTask.assignment.subjectId
                                     handler:^(WKStudyMaterials * _Nullable studyMaterials) {
    _activeStudyMaterials = studyMaterials;
  }];
  
  // Choose whether to ask the meaning or the reading.
  if (_activeTask.answeredMeaning) {
    _activeTaskType = kWKTaskTypeReading;
  } else if (_activeTask.answeredReading) {
    _activeTaskType = kWKTaskTypeMeaning;
  } else {
    _activeTaskType = (WKTaskType)arc4random_uniform(kWKTaskType_Max);
  }
  
  // Fill the question labels.
  NSString *subjectTypePrompt;
  NSString *taskTypePrompt;
  NSArray *questionGradient;
  NSArray *promptGradient;
  UIColor *promptTextColor;
  
  switch (_activeTask.assignment.subjectType) {
    case WKSubject_Type_Kanji:
      subjectTypePrompt = @"Kanji";
      questionGradient = kKanjiGradient;
      break;
    case WKSubject_Type_Radical:
      subjectTypePrompt = @"Radical";
      questionGradient = kRadicalGradient;
      break;
    case WKSubject_Type_Vocabulary:
      subjectTypePrompt = @"Vocabulary";
      questionGradient = kVocabularyGradient;
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
  
  [UIView animateWithDuration:0.2f animations:^{
    [self.promptLabel setAttributedText:prompt];
    [self.questionLabel setText:_activeSubject.japanese];
    _questionGradient.colors = questionGradient;
    _promptGradient.colors = promptGradient;
    _promptLabel.textColor = promptTextColor;
  }];
  
  [_answerField becomeFirstResponder];
}

#pragma mark - Answering

- (void)submit {
  WKAnswerCheckerResult result =
      CheckAnswer(_answerField.text, _activeSubject, _activeStudyMaterials, _activeTaskType);
  switch (result) {
    case kWKAnswerPrecise:
    case kWKAnswerImprecise:
      [self markAnswer:true];
      break;
    case kWKAnswerIncorrect:
      [self markAnswer:false];
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
  view.transform = CGAffineTransformMakeTranslation(20, 0);
  [UIView animateWithDuration:0.8 delay:0.0 usingSpringWithDamping:0.2 initialSpringVelocity:2.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
    view.transform = CGAffineTransformIdentity;
  } completion:nil];
}

- (void)markAnswer:(bool)correct {
  // Mark the task.
  switch (_activeTaskType) {
    case kWKTaskTypeMeaning:
      NSLog(@"Meaning %s", correct ? "correct" : "incorrect");
      if (!_activeTask.answer.hasMeaningWrong) {
        _activeTask.answer.meaningWrong = !correct;
        NSLog(@"That was the first meaning answer");
      }
      _activeTask.answeredMeaning = correct;
      break;
    case kWKTaskTypeReading:
      NSLog(@"Reading %s", correct ? "correct" : "incorrect");
      if (!_activeTask.answer.hasReadingWrong) {
        _activeTask.answer.readingWrong = !correct;
        NSLog(@"That was the first reading answer");
      }
      _activeTask.answeredReading = correct;
      break;
    case kWKTaskType_Max:
      abort();
  }
  
  // Update stats.
  _tasksAnswered ++;
  if (correct) {
    _tasksAnsweredCorrectly ++;
  }
  
  // Remove it from the active queue if that was the last part.
  if (_activeTask.answeredMeaning && _activeTask.answeredReading) {
    NSLog(@"Done both meaning and reading for this task!");
    _reviewsCompleted ++;
    [_activeQueue removeObjectAtIndex:_activeTaskIndex];
    [self refillActiveQueue];
  }
  
  // Show a new task if it was correct.
  if (correct) {
    [self randomTask];
    return;
  }
  
  // Otherwise show the correct answer.
  NSString *subjectDetailsHTML = [_subjectDetailsRenderer renderSubjectDetails:_activeSubject];
  [_subjectDetailsView loadHTMLString:subjectDetailsHTML baseURL:nil];
  _subjectDetailsView.hidden = NO;
  _answerField.enabled = NO;
}

- (IBAction)submitButtonPressed:(id)sender {
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

- (IBAction)backgroundTouched:(id)sender {
  [self.view endEditing:NO];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  if ([navigationAction.request.URL.scheme isEqualToString:@"wk"]) {
    // TODO.
    decisionHandler(WKNavigationActionPolicyCancel);
  } else {
    decisionHandler(WKNavigationActionPolicyAllow);
  }
}

@end

