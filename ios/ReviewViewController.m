//
//  ReviewViewController.m
//  Wordlist
//
//  Created by David Sansome on 29/7/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "AnswerChecker.h"
#import "LanguageSpecificTextField.h"
#import "ReviewViewController.h"
#import "proto/Wanikani+Convenience.h"

static const int kActiveQueueSize = 10;

@interface ReviewViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UILabel *promptLabel;
@property (weak, nonatomic) IBOutlet LanguageSpecificTextField *answerField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UILabel *correctAnswerLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;

@property (weak, nonatomic) IBOutlet UILabel *successRateLabel;
@property (weak, nonatomic) IBOutlet UILabel *doneLabel;
@property (weak, nonatomic) IBOutlet UILabel *queueLabel;
@property (weak, nonatomic) IBOutlet UIImageView *successRateIcon;
@property (weak, nonatomic) IBOutlet UIImageView *doneIcon;
@property (weak, nonatomic) IBOutlet UIImageView *queueIcon;

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) NSMutableArray<ReviewItem *> *activeQueue;
@property (nonatomic) NSMutableArray<ReviewItem *> *reviewQueue;

@property (nonatomic, readonly) int activeTaskIndex;  // An index into activeQueue;
@property (nonatomic, readonly) WKTaskType activeTaskType;
@property (nonatomic, readonly) ReviewItem *activeTask;
@property (nonatomic, readonly) WKSubject *activeSubject;

@property (nonatomic) int reviewsCompleted;
@property (nonatomic) int tasksAnsweredCorrectly;
@property (nonatomic) int tasksAnswered;

@end

@implementation ReviewViewController

#pragma mark - Constructors

- (instancetype)initWithItems:(NSArray<ReviewItem *> *)items
                   dataLoader:(DataLoader *)dataLoader {
  if (self = [super initWithNibName:nil bundle:nil]) {
    NSLog(@"Starting review with %lu items", (unsigned long)items.count);
    _dataLoader = dataLoader;
    _reviewQueue = [NSMutableArray arrayWithArray:items];
    _activeQueue = [NSMutableArray array];
    [self refillActiveQueue];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self addShadowToView:self.successRateIcon];
  [self addShadowToView:self.successRateLabel];
  [self addShadowToView:self.doneIcon];
  [self addShadowToView:self.doneLabel];
  [self addShadowToView:self.queueIcon];
  [self addShadowToView:self.queueLabel];
  
  self.answerField.delegate = self;
}

- (void)addShadowToView:(UIView *)view {
  view.layer.shadowColor = [UIColor blackColor].CGColor;
  view.layer.shadowOffset = CGSizeMake(1, 1);
  view.layer.shadowOpacity = 0.6;
  view.layer.shadowRadius = 1.5;
  view.clipsToBounds = NO;
}

- (void)viewWillAppear:(BOOL)animated {
  [self randomTask];
  [super viewWillAppear:animated];
  [self.answerField becomeFirstResponder];
}

#pragma mark - Setup

- (void)refillActiveQueue {
  while (self.activeQueue.count < kActiveQueueSize &&
         self.reviewQueue.count != 0) {
    const NSUInteger i = arc4random_uniform((uint32_t)self.reviewQueue.count);
    ReviewItem * item = [self.reviewQueue objectAtIndex:i];
    [self.reviewQueue removeObjectAtIndex:i];
    [self.activeQueue addObject:item];
  }
}

- (void)randomTask {
  // Update the progress labels.
  if (self.tasksAnswered == 0) {
    self.successRateLabel.text = @"100%";
  } else {
    self.successRateLabel.text = [NSString stringWithFormat:@"%d%%",
                                  (int)(self.tasksAnsweredCorrectly / self.tasksAnswered)];
  }
  int queueLength = (int)(self.activeQueue.count + self.reviewQueue.count);
  self.doneLabel.text = [NSString stringWithFormat:@"%d", self.reviewsCompleted];
  self.queueLabel.text = [NSString stringWithFormat:@"%d", queueLength];
  
  // Update the progress bar.
  int totalLength = queueLength + self.reviewsCompleted;
  if (totalLength == 0) {
    self.progressBar.progress = 0.0;
  } else {
    self.progressBar.progress = (double)(self.reviewsCompleted) / totalLength;
  }
  
  // Choose a random task from the active queue.
  if (self.activeQueue.count == 0) {
    return;
  }
  _activeTaskIndex = arc4random_uniform((uint32_t)self.activeQueue.count);
  _activeTask = self.activeQueue[self.activeTaskIndex];
  _activeSubject = [self.dataLoader loadSubject:self.activeTask.assignment.subjectId];
  
  // Choose whether to ask the meaning or the reading.
  if (self.activeTask.passedMeaning) {
    _activeTaskType = kWKTaskTypeReading;
  } else if (self.activeTask.passedReading) {
    _activeTaskType = kWKTaskTypeMeaning;
  } else {
    _activeTaskType = (WKTaskType)arc4random_uniform(kWKTaskType_Max);
  }
  
  // Fill the question labels.
  NSString *subjectTypePrompt;
  NSString *taskTypePrompt;
  
  switch (self.activeTask.assignment.subjectType) {
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
  switch (self.activeTaskType) {
    case kWKTaskTypeMeaning:
      taskTypePrompt = @"Meaning";
      break;
    case kWKTaskTypeReading:
      taskTypePrompt = @"Reading";
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
  [self.promptLabel setAttributedText:prompt];
  [self.questionLabel setText:self.activeSubject.japanese];
  [self.correctAnswerLabel setHidden:YES];
}

#pragma mark - Answering

- (void)submit {
  WKAnswerCheckerResult result = CheckAnswer(_answerField.text, _activeSubject, _activeTaskType);
  NSLog(@"Result %d", result);
}

- (IBAction)submitButtonPressed:(id)sender {
  [self submit];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [self submit];
  return YES;
}

- (IBAction)backgroundTouched:(id)sender {
  [self.view endEditing:NO];
}

@end

