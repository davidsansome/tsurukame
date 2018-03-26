#import "LoginViewController.h"

#import "Client.h"
#import "UserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

NSNotificationName kLoginCompleteNotification = @"kLoginCompleteNotification";
NSNotificationName kLogoutNotification = @"kLogoutNotification";

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
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIButton *forwardButton;
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation LoginViewController {
  WKWebsiteDataStore *_dataStore;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _dataStore = _webView.configuration.websiteDataStore;
  _webView.navigationDelegate = self;
  _webView.translatesAutoresizingMaskIntoConstraints = NO;
  
  [_webView addObserver:self
             forKeyPath:@"estimatedProgress"
                options:NSKeyValueObservingOptionNew
                context:nil];
  [_webView addObserver:self
             forKeyPath:@"loading"
                options:NSKeyValueObservingOptionNew
                context:nil];
  
  [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:kLoginURL]]];
}

- (IBAction)didTapBack:(id)sender {
  [_webView goBack];
}

- (IBAction)didTapForward:(id)sender {
  [_webView goForward];
}

- (IBAction)didTapRefresh:(id)sender {
  [_webView reload];
}

- (void)updateNavigationButtons {
  _backButton.enabled = _webView.canGoBack;
  _forwardButton.enabled = _webView.canGoForward;
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(nullable void *)context {
  if ([keyPath isEqualToString:@"estimatedProgress"]) {
    [_progressView setProgress:_webView.estimatedProgress animated:YES];
  } else if ([keyPath isEqualToString:@"loading"]) {
    [_progressView setHidden:!_webView.loading];
    [self updateNavigationButtons];
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - WKNavigationDelegate

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

- (void)webView:(WKWebView *)webView
didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
  [_titleLabel setText:webView.URL.host];
  [self updateNavigationButtons];
}

@end

NS_ASSUME_NONNULL_END
