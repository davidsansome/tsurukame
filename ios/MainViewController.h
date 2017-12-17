#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DataLoader;
@class LocalCachingClient;
@class Reachability;

@interface MainViewController : UITableViewController

@property(nonatomic) DataLoader *dataLoader;
@property(nonatomic) Reachability *reachability;
@property(nonatomic) LocalCachingClient *localCachingClient;

@end

NS_ASSUME_NONNULL_END
