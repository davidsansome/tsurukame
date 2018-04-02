#import "SettingsViewController.h"

#import "LoginViewController.h"
#import "UserDefaults.h"

@interface SettingsViewController ()

@property (strong, nonatomic) IBOutlet UISwitch *particleExplosionSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *levelUpPopupSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *plusOneSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *enableCheatsSwitch;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _particleExplosionSwitch.on = UserDefaults.animateParticleExplosion;
  _levelUpPopupSwitch.on = UserDefaults.animateLevelUpPopup;
  _plusOneSwitch.on = UserDefaults.animatePlusOne;
  _enableCheatsSwitch.on = UserDefaults.enableCheats;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

- (IBAction)switchValueChanged:(id)sender {
  UserDefaults.animateParticleExplosion = _particleExplosionSwitch.on;
  UserDefaults.animateLevelUpPopup = _levelUpPopupSwitch.on;
  UserDefaults.animatePlusOne = _plusOneSwitch.on;
  UserDefaults.enableCheats = _enableCheatsSwitch.on;
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

@end
