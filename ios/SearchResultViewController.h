#import <UIKit/UIKit.h>

@class DataLoader;
@class LocalCachingClient;

@interface SearchResultViewController : UITableViewController <UISearchResultsUpdating>

@property(nonatomic) DataLoader *dataLoader;
@property(nonatomic) LocalCachingClient *localCachingClient;

@end
