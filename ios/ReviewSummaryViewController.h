#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "ReviewItem.h"

@interface ReviewSummaryViewController : UITableViewController

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) LocalCachingClient *localCachingClient;
@property (nonatomic) NSArray<ReviewItem *> *items;

@end
