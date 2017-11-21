//
//  ReviewViewController.m
//  Wordlist
//
//  Created by David Sansome on 29/7/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "LanguageSpecificTextField.h"
#import "ReviewViewController.h"

typedef enum : NSUInteger {
  Correct,
  Incorrect,
  Invalid,
} AnswerCorrectness;

@interface ReviewViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UILabel *promptLabel;
@property (weak, nonatomic) IBOutlet LanguageSpecificTextField *answerField;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UILabel *correctAnswerLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *successRateLabel;


@property (nonatomic) NSManagedObjectContext* ctx;

@property (nonatomic) int reviewsCompleted;
@property (nonatomic) int tasksAnsweredCorrectly;
@property (nonatomic) int tasksAnswered;

@end

@implementation ReviewViewController

#pragma mark - Constructors

- (instancetype)initWithContext:(NSManagedObjectContext*)ctx {
  if (self = [super init]) {
    _ctx = ctx;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.answerField.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
  // TODO: tasks
  [super viewWillAppear:animated];
  [self.answerField becomeFirstResponder];
}

#pragma mark - Setup

- (void)createTasks {
  // TODO: tasks
  self.reviewsCompleted = 0;
  self.tasksAnsweredCorrectly = 0;
  self.tasksAnswered = 0;
  
  // TODO: tasks
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

