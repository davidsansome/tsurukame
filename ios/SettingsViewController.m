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

#import "SettingsViewController.h"

#import "LocalCachingClient.h"
#import "LoginViewController.h"
#import "UserDefaults.h"

static const int kReviewsSectionIndex = 1;
static const int kMeaningReadingOrderRowIndex = 2;

@interface SettingsViewController ()

@property (strong, nonatomic) IBOutlet UISwitch *particleExplosionSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *levelUpPopupSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *plusOneSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *groupMeaningReadingSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *showAnswerImmediatelySwitch;
@property (strong, nonatomic) IBOutlet UISwitch *enableCheatsSwitch;

@property (weak, nonatomic) IBOutlet UILabel *reviewOrderSubtitle;
@property (weak, nonatomic) IBOutlet UILabel *taskOrderSubtitle;

@end

@implementation SettingsViewController {
  NSIndexPath *_groupMeaningReadingIndexPath;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _groupMeaningReadingIndexPath =
      [NSIndexPath indexPathForRow:kMeaningReadingOrderRowIndex
                         inSection:kReviewsSectionIndex];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
  
  _particleExplosionSwitch.on = UserDefaults.animateParticleExplosion;
  _levelUpPopupSwitch.on = UserDefaults.animateLevelUpPopup;
  _plusOneSwitch.on = UserDefaults.animatePlusOne;
  _showAnswerImmediatelySwitch.on = UserDefaults.showAnswerImmediately;
  _enableCheatsSwitch.on = UserDefaults.enableCheats;
  
  _groupMeaningReadingSwitch.on = UserDefaults.groupMeaningReading;
  _enableCheatsSwitch.on = UserDefaults.enableCheats;
  
  switch (UserDefaults.reviewOrder) {
    case ReviewOrder_Random:
      [_reviewOrderSubtitle setText:@"Random"];
      break;
    case ReviewOrder_BySRSLevel:
      [_reviewOrderSubtitle setText:@"SRS level"];
      break;
    case ReviewOrder_CurrentLevelFirst:
      [_reviewOrderSubtitle setText:@"Current level first"];
      break;
  }
  
  if (UserDefaults.meaningFirst) {
    [_taskOrderSubtitle setText:@"Meaning first"];
  } else {
    [_taskOrderSubtitle setText:@"Reading first"];
  }
  
  [self setIndexPath:_groupMeaningReadingIndexPath isHidden:!_groupMeaningReadingSwitch.on];
}

- (IBAction)switchValueChanged:(id)sender {
  UserDefaults.animateParticleExplosion = _particleExplosionSwitch.on;
  UserDefaults.animateLevelUpPopup = _levelUpPopupSwitch.on;
  UserDefaults.animatePlusOne = _plusOneSwitch.on;
  
  UserDefaults.groupMeaningReading = _groupMeaningReadingSwitch.on;
  UserDefaults.showAnswerImmediately = _showAnswerImmediatelySwitch.on;
  UserDefaults.enableCheats = _enableCheatsSwitch.on;
  
  [self setIndexPath:_groupMeaningReadingIndexPath isHidden:!_groupMeaningReadingSwitch.on];
}

- (IBAction)didTapLogOut:(id)sender {
  __weak SettingsViewController *weakSelf = self;
  UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                             message:nil
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [c addAction:[UIAlertAction actionWithTitle:@"Log out"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction * _Nonnull action) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kLogoutNotification object:weakSelf];
  }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (IBAction)didTapSendBugReport:(id)sender {
  NSURL *url = [LocalCachingClient databaseFileUrl];
  UIActivityViewController *c = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                  applicationActivities:nil];
  [self presentViewController:c animated:YES completion:nil];
}

@end
