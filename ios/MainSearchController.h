#import "DataLoader.h"
#import "Reachability.h"
#import "LocalCachingClient.h"

#import <UIKit/UIKit.h>

@class MainViewController;

@interface MainSearchController : UIViewController

@property(nonatomic) DataLoader *dataLoader;
@property(nonatomic) Reachability *reachability;
@property(nonatomic) LocalCachingClient *localCachingClient;

@property(nonatomic, readonly) MainViewController *mainViewController;

@end
