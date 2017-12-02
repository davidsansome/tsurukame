//
//  ReviewViewController.m
//  Wordlist
//
//  Created by David Sansome on 29/7/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "LanguageSpecificTextField.h"
#import "ReviewViewController.h"
#import "proto/Wanikani+Convenience.h"

typedef enum : NSUInteger {
  kTaskTypeReading,
  kTaskTypeMeaning,
} TaskType;

static const int kActiveQueueSize = 10;

@interface ReviewViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UILabel *promptLabel;
@property (weak, nonatomic) IBOutlet LanguageSpecificTextField *answerField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UILabel *correctAnswerLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *successRateLabel;


@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) NSMutableArray<ReviewItem *> *activeQueue;
@property (nonatomic) NSMutableArray<ReviewItem *> *reviewQueue;

@property (nonatomic, readonly) int activeTaskIndex;  // An index into activeQueue;
@property (nonatomic, readonly) TaskType activeTaskType;
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
  
  self.answerField.delegate = self;
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
  if (self.activeQueue.count == 0) {
    return;
  }
  _activeTaskIndex = arc4random_uniform((uint32_t)self.activeQueue.count);
  _activeTask = self.activeQueue[self.activeTaskIndex];
  _activeSubject = [self.dataLoader loadSubject:self.activeTask.assignment.subjectId];
  
  if (self.activeTask.passedMeaning) {
    _activeTaskType = kTaskTypeReading;
  } else if (self.activeTask.passedReading) {
    _activeTaskType = kTaskTypeMeaning;
  } else {
    _activeTaskType = (TaskType)arc4random_uniform(2);
  }
  
  switch (self.activeTaskType) {
    case kTaskTypeMeaning:
      [self.questionLabel setText:self.activeSubject.japanese];
      break;
      
    case kTaskTypeReading:
      [self.questionLabel setText:self.activeSubject.primaryMeaning];
      break;
  }
}

#pragma mark - Answering

- (void)submit {
  
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

