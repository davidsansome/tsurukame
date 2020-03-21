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

#import "LoginViewController.h"

#import "Tsurukame-Swift.h"

#import <PromiseKit/PromiseKit.h>

NS_ASSUME_NONNULL_BEGIN

NSNotificationName kLogoutNotification = @"kLogoutNotification";

static NSString *const kPrivacyPolicyURL =
    @"https://github.com/davidsansome/tsurukame/wiki/Privacy-Policy";

@interface LoginViewController () <UITextFieldDelegate>

@property(weak, nonatomic) IBOutlet UILabel *signInLabel;
@property(weak, nonatomic) IBOutlet UITextField *usernameField;
@property(weak, nonatomic) IBOutlet UITextField *passwordField;
@property(weak, nonatomic) IBOutlet UIButton *signInButton;
@property(weak, nonatomic) IBOutlet UILabel *privacyPolicyLabel;
@property(weak, nonatomic) IBOutlet UIButton *privacyPolicyButton;
@property(weak, nonatomic) IBOutlet UIView *activityIndicatorOverlay;
@property(weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation LoginViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [TKMStyle addShadowToView:_signInLabel offset:0.f opacity:1.f radius:5.f];
  [TKMStyle addShadowToView:_privacyPolicyLabel offset:0.f opacity:1.f radius:2.f];
  [TKMStyle addShadowToView:_privacyPolicyButton offset:0.f opacity:1.f radius:2.f];

  if (_forcedUsername.length) {
    _usernameField.text = _forcedUsername;
    _usernameField.enabled = NO;
  }

  _usernameField.delegate = self;
  _passwordField.delegate = self;

  [_usernameField addTarget:self
                     action:@selector(textFieldDidChange:)
           forControlEvents:UIControlEventEditingChanged];
  [_passwordField addTarget:self
                     action:@selector(textFieldDidChange:)
           forControlEvents:UIControlEventEditingChanged];
  [self textFieldDidChange:_usernameField];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = YES;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if (textField == _usernameField) {
    [_passwordField becomeFirstResponder];
  } else if (textField == _passwordField) {
    [self didTapSignInButton:self];
  }
  return YES;
}

- (void)textFieldDidChange:(UITextField *)textField {
  bool enabled = _usernameField.text.length != 0 && _passwordField.text.length != 0;
  _signInButton.enabled = enabled;
  _signInButton.backgroundColor = enabled ? TKMStyle.radicalColor2 : TKMStyleColor.grey33;
}

#pragma mark - Sign In flow

- (IBAction)didTapSignInButton:(id)sender {
  if (!_signInButton.enabled) {
    return;
  }
  [self showActivityIndicatorOverlay:true];

  WaniKaniWebClient *client = [[WaniKaniWebClient alloc] init];
  AnyPromise *promise = [client loginWithUsername:_usernameField.text password:_passwordField.text];
  promise
      .then(^(LoginResult *result) {
        NSLog(@"Login success!");
        Settings.userCookie = result.cookie;
        Settings.userApiToken = result.apiToken;
        Settings.userEmailAddress = result.emailAddress;

        [_delegate loginComplete];
      })
      .catch(^(NSError *error) {
        NSString *message;
        if ([error.domain isEqual:WaniKaniWebClientErrorDomain]) {
          message = [WaniKaniWebClient errorDescription:error.code];
        } else {
          message = error.localizedDescription;
        }
        [self showLoginError:message];
      });
}

#pragma mark - Errors and competion

- (void)showLoginError:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Error"
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [c addAction:[UIAlertAction actionWithTitle:@"Close"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];
    [self presentViewController:c animated:YES completion:nil];
    [self showActivityIndicatorOverlay:false];
  });
}

- (void)showActivityIndicatorOverlay:(bool)visible {
  [self.view endEditing:YES];
  _activityIndicatorOverlay.hidden = !visible;
  _activityIndicator.hidden = !visible;
  if (visible) {
    [_activityIndicator startAnimating];
  } else {
    [_activityIndicator stopAnimating];
  }
}

#pragma mark - Privacy policy

- (IBAction)didTapPrivacyPolicyButton:(id)sender {
  NSURL *url = [NSURL URLWithString:kPrivacyPolicyURL];
  NSDictionary<NSString *, id> *options = [NSDictionary dictionary];
  [[UIApplication sharedApplication] openURL:url options:options completionHandler:nil];
}

@end

NS_ASSUME_NONNULL_END
