#import <UIKit/UIKit.h>

@class DataLoader;
@class WKSubject;

@protocol SearchResultViewControllerDelegate <NSObject>

- (void)searchResultSelected:(WKSubject *)subject;

@end

@interface SearchResultViewController : UITableViewController <UISearchResultsUpdating>

@property(nonatomic) DataLoader *dataLoader;
@property(nonatomic, weak) id<SearchResultViewControllerDelegate> delegate;

@end
