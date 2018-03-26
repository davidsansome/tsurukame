#import "SettingsViewController.h"

#import "LoginViewController.h"

@interface SettingsViewController ()

@property (strong, nonatomic) IBOutlet UISwitch *particleExplosionSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *levelUpPopupSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *plusOneSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *enableCheatsSwitch;

@end

@implementation SettingsViewController

- (IBAction)switchValueChanged:(id)sender {
  NSLog(@"Switch changed");
}

- (IBAction)didTapLogOut:(id)sender {
  __weak SettingsViewController *weakSelf = self;
  UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                             message:nil
                                                      preferredStyle:UIAlertControllerStyleActionSheet];
  [c addAction:[UIAlertAction actionWithTitle:@"Log out"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction * _Nonnull action) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kLogoutNotification object:weakSelf];
  }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

@end
