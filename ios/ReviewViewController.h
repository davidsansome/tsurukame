#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "ReviewItem.h"

@interface ReviewViewController : UIViewController

@property(nonatomic, assign) DataLoader *dataLoader;
@property(nonatomic, assign) LocalCachingClient *localCachingClient;

- (void)startReviewWithItems:(NSArray<ReviewItem *> *)items;

@end
