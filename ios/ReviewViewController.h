#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "ReviewItem.h"

@interface ReviewViewController : UIViewController

- (instancetype)initWithItems:(NSArray<ReviewItem *> *)items
                   dataLoader:(DataLoader *)dataLoader
                       client:(LocalCachingClient *)client NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end
