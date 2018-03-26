#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kLoginCompleteNotification;
extern NSNotificationName kLogoutNotification;

@interface LoginWebView : WKWebView
@end

@interface LoginViewController : UIViewController
@end

NS_ASSUME_NONNULL_END
