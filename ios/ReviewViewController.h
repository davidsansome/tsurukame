#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "ReviewItem.h"

@class ReviewViewController;

@protocol ReviewViewControllerDelegate <NSObject>

- (bool)reviewViewController:(ReviewViewController *)reviewViewController
             allowsCheatsFor:(ReviewItem *)reviewItem;

- (void)reviewViewControllerTappedBackButton:(ReviewViewController *)reviewViewController;
- (void)reviewViewController:(ReviewViewController *)reviewViewController
          finishedReviewItem:(ReviewItem *)reviewItem;
- (void)reviewViewControllerFinishedAllReviewItems:(ReviewViewController *)reviewViewController;

@end


@interface ReviewViewController : UIViewController

// Must set these prior to starting.
@property(nonatomic, assign) DataLoader *dataLoader;
@property(nonatomic, assign) LocalCachingClient *localCachingClient;
- (void)startReviewWithItems:(NSArray<ReviewItem *> *)items;

@property(nonatomic, weak) id<ReviewViewControllerDelegate> delegate;

@property(nonatomic) bool wrappingUp;

@end


@interface DefaultReviewViewControllerDelegate : NSObject<ReviewViewControllerDelegate>
@end
