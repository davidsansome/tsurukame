#import "LoginViewController.h"

#import "Client.h"
#import "UserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

NSNotificationName kLoginCompleteNotification = @"kLoginCompleteNotification";

static NSString *kLoginURL = @"https://www.wanikani.com/login";
static NSString *kDashboardURL = @"https://www.wanikani.com/dashboard";

@implementation LoginWebView

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
  CGRect frame = [[UIScreen mainScreen] bounds];
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
  
  return [super initWithFrame:frame configuration:config];
}

@end

@interface LoginViewController () <WKNavigationDelegate>

@property (weak, nonatomic) IBOutlet WKWebView *webView;

@end

@implementation LoginViewController {
  WKWebsiteDataStore *_dataStore;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _dataStore = _webView.configuration.websiteDataStore;
  _webView.navigationDelegate = self;
  _webView.translatesAutoresizingMaskIntoConstraints = NO;
  [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:kLoginURL]]];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  if ([navigationAction.request.URL.absoluteString isEqualToString:kDashboardURL]) {
    [_dataStore.httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
      for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@(kWanikaniSessionCookieName)]) {
          // Store the user cookie.
          UserDefaults.userCookie = cookie.value;
          
          // Show a progress page while we steal the API token.
          UIViewController *progressController =
              [self.storyboard instantiateViewControllerWithIdentifier:@"loginProgress"];
          [self.navigationController pushViewController:progressController animated:YES];
          
          [Client getApiTokenForCookie:cookie.value handler:^(NSError * _Nullable error,
                                                              NSString * _Nullable apiToken,
                                                              NSString * _Nullable emailAddress) {
            dispatch_async(dispatch_get_main_queue(), ^{
              if (error) {
                [self.navigationController popToRootViewControllerAnimated:YES];
                NSLog(@"Login error: %@", error);
                return;
              }
              
              UserDefaults.userEmailAddress = emailAddress;
              UserDefaults.userApiToken = apiToken;
              
              [[NSNotificationCenter defaultCenter] postNotificationName:kLoginCompleteNotification
                                                                  object:self];
            });
          }];
        }
      }
    }];
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
  }
  decisionHandler(WKNavigationActionPolicyAllow);
}

@end

NS_ASSUME_NONNULL_END
