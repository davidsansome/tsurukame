#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "ReviewItem.h"

@interface LessonsViewController : UIViewController <
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate>

@property(nonatomic, assign) DataLoader *dataLoader;
@property(nonatomic, assign) LocalCachingClient *localCachingClient;

@property(nonatomic, copy) NSArray<ReviewItem *> *items;

@end
