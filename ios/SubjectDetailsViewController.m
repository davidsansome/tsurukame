//
//  SubjectDetailsViewController.m
//  wk
//
//  Created by David Sansome on 10/12/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "SubjectDetailsViewController.h"

static NSArray<id> *kRadicalGradient;
static NSArray<id> *kKanjiGradient;
static NSArray<id> *kVocabularyGradient;
static NSArray<id> *kReadingGradient;
static NSArray<id> *kMeaningGradient;

@interface SubjectDetailsViewController ()

@end

@implementation SubjectDetailsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kRadicalGradient = @[(id)[UIColor colorWithRed:0.000f green:0.667f blue:1.000f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.000f green:0.576f blue:0.867f alpha:1.0f].CGColor];
    kKanjiGradient = @[(id)[UIColor colorWithRed:1.000f green:0.000f blue:0.667f alpha:1.0f].CGColor,
                       (id)[UIColor colorWithRed:0.867f green:0.000f blue:0.576f alpha:1.0f].CGColor];
    kVocabularyGradient = @[(id)[UIColor colorWithRed:0.000f green:0.667f blue:1.000f alpha:1.0f].CGColor,
                            (id)[UIColor colorWithRed:0.576f green:0.000f blue:0.867f alpha:1.0f].CGColor];
    kReadingGradient = @[(id)[UIColor colorWithRed:0.333f green:0.333f blue:0.333f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.200f green:0.200f blue:0.200f alpha:1.0f].CGColor];
    kMeaningGradient = @[(id)[UIColor colorWithRed:0.933f green:0.933f blue:0.933f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.600f green:0.600f blue:0.600f alpha:1.0f].CGColor];
  });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
