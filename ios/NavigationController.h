#import <UIKit/UIKit.h>

@protocol NavigationControllerDelegate <NSObject>
- (bool)canSwipeToGoBack;
@end

@interface NavigationController : UINavigationController
@end
