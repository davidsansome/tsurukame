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
#import "Tables/TKMSwitchModelItem.h"
#import "Tables/TKMTableModel.h"
#import "UserDefaults.h"

@interface SettingsViewController ()
@end

@implementation SettingsViewController {
  TKMTableModel *_model;
  NSIndexPath *_groupMeaningReadingIndexPath;
  NSIndexPath *_randomFontsIndexPath;
}

- (void)rerender {
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];

  [model addSection:@"Animations" footer:@"You can turn off any animations you find distracting"];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Particle explosion"
                          subtitle:nil
                                on:UserDefaults.animateParticleExplosion
                            target:self
                            action:@selector(animateParticleExplosionSwitchChanged:)]];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Level up popup"
                          subtitle:nil
                                on:UserDefaults.animateLevelUpPopup
                            target:self
                            action:@selector(animateLevelUpPopupSwitchChanged:)]];
  [model
      addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                  title:@"+1"
                                               subtitle:nil
                                                     on:UserDefaults.animatePlusOne
                                                 target:self
                                                 action:@selector(animatePlusOneSwitchChanged:)]];

  [model addSection:@"Reviews"];
  [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Review order"
                                              subtitle:self.reviewOrderValueText
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapReviewOrder:)]];

  [model addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                     title:@"Jitai"
                                                  subtitle:@"Use a random font for each review"
                                                        on:UserDefaults.usedFonts
                                                    target:self
                                                    action:@selector(randomFontsSwitchChanged:)]];

  _randomFontsIndexPath = [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Selected Fonts"
                                              subtitle:self.selectedFontsSubtitle
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapRandomFonts:)]
       hidden:!UserDefaults.randomFontsEnabled];

  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleSubtitle
                             title:@"Back-to-back"
                          subtitle:@"Group Meaning and Reading together"
                                on:UserDefaults.groupMeaningReading
                            target:self
                            action:@selector(groupMeaningReadingSwitchChanged:)]];
  _groupMeaningReadingIndexPath = [model
      addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleValue1
                                                 title:@"Back-to-back order"
                                              subtitle:self.taskOrderValueText
                                         accessoryType:UITableViewCellAccessoryDisclosureIndicator
                                                target:self
                                                action:@selector(didTapTaskOrder:)]
       hidden:!UserDefaults.groupMeaningReading];
  [model addItem:[[TKMSwitchModelItem alloc]
                     initWithStyle:UITableViewCellStyleDefault
                             title:@"Reveal answer automatically"
                          subtitle:nil
                                on:UserDefaults.showAnswerImmediately
                            target:self
                            action:@selector(showAnswerImmediatelySwitchChanged:)]];
  [model addItem:[[TKMSwitchModelItem alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                     title:@"Allow cheating"
                                                  subtitle:@"Ignore Typos and Add Synonym"
                                                        on:UserDefaults.enableCheats
                                                    target:self
                                                    action:@selector(enableCheatsSwitchChanged:)]];

  [model addSection];
  [model addItem:[[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                                    title:@"Offline audio"
                                                 subtitle:nil
                                            accessoryType:UITableViewCellAccessoryNone
                                                   target:self
                                                   action:@selector(didTapOfflineAudio:)]];

  [model addSection];
  [model addItem:[[TKMBasicModelItem alloc]
                     initWithStyle:UITableViewCellStyleSubtitle
                             title:@"Export local database"
                          subtitle:@"To attach to bug reports or email to the developer"
                     accessoryType:UITableViewCellAccessoryDisclosureIndicator
                            target:self
                            action:@selector(didTapSendBugReport:)]];

  TKMBasicModelItem *logOutItem =
      [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                         title:@"Log out"
                                      subtitle:nil
                                 accessoryType:UITableViewCellAccessoryNone
                                        target:self
                                        action:@selector(didTapLogOut:)];
  logOutItem.textColor = [UIColor redColor];
  [model addItem:logOutItem];

  _model = model;
  [model reloadTable];
}

- (NSString *)selectedFontsSubtitle {
  NSArray<TKMFont *> *enabledFonts = [TKMFontLoader getEnabledFonts];
  if (enabledFonts.count == 1) {
    return enabledFonts.firstObject.fontName;
  } else {
    return [NSString stringWithFormat:@"%lu fonts", enabledFonts.count];
  }
}

- (NSString *)reviewOrderValueText {
  switch (UserDefaults.reviewOrder) {
    case ReviewOrder_Random:
      return @"Random";
    case ReviewOrder_BySRSLevel:
      return @"SRS level";
    case ReviewOrder_CurrentLevelFirst:
      return @"Current level first";
  }
  return nil;
}

- (NSString *)taskOrderValueText {
  if (UserDefaults.meaningFirst) {
    return @"Meaning first";
  } else {
    return @"Reading first";
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;

  [self rerender];
}

- (void)animateParticleExplosionSwitchChanged:(UISwitch *)switchView {
  UserDefaults.animateParticleExplosion = switchView.on;
}

- (void)animateLevelUpPopupSwitchChanged:(UISwitch *)switchView {
  UserDefaults.animateLevelUpPopup = switchView.on;
}

- (void)animatePlusOneSwitchChanged:(UISwitch *)switchView {
  UserDefaults.animatePlusOne = switchView.on;
}

- (void)randomFontsSwitchChanged:(UISwitch *)switchView {
  UserDefaults.randomFontsEnabled = switchView.on;
  [_model setIndexPath:_randomFontsIndexPath isHidden:!switchView.on];
}

- (void)groupMeaningReadingSwitchChanged:(UISwitch *)switchView {
  UserDefaults.groupMeaningReading = switchView.on;
  [_model setIndexPath:_groupMeaningReadingIndexPath isHidden:!switchView.on];
}

- (void)showAnswerImmediatelySwitchChanged:(UISwitch *)switchView {
  UserDefaults.showAnswerImmediately = switchView.on;
}

- (void)enableCheatsSwitchChanged:(UISwitch *)switchView {
  UserDefaults.enableCheats = switchView.on;
}

- (void)didTapReviewOrder:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"reviewOrder" sender:self];
}

- (void)didTapRandomFonts:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"randomFonts" sender:self];
}

- (void)didTapTaskOrder:(TKMBasicModelItem *)item {
  [self performSegueWithIdentifier:@"taskOrder" sender:self];
}

- (void)didTapOfflineAudio:(id)sender {
  [self performSegueWithIdentifier:@"offlineAudio" sender:self];
}

- (void)didTapLogOut:(id)sender {
  __weak SettingsViewController *weakSelf = self;
  UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                             message:nil
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [c addAction:[UIAlertAction
                   actionWithTitle:@"Log out"
                             style:UIAlertActionStyleDestructive
                           handler:^(UIAlertAction *_Nonnull action) {
                             NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
                             [nc postNotificationName:kLogoutNotification object:weakSelf];
                           }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)didTapSendBugReport:(id)sender {
  NSURL *url = [LocalCachingClient databaseFileUrl];
  UIActivityViewController *c = [[UIActivityViewController alloc] initWithActivityItems:@[ url ]
                                                                  applicationActivities:nil];
  [self presentViewController:c animated:YES completion:nil];
}

@end
