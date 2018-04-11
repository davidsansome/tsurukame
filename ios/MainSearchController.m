#import "MainSearchController.h"

#import "MainViewController.h"
#import "SearchResultViewController.h"

@interface MainSearchController ()
@property (weak, nonatomic) IBOutlet UIView *embeddedView;
@end

@implementation MainSearchController {
  UISearchController *_searchController;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  SearchResultViewController *searchResultsViewController =
      [self.storyboard instantiateViewControllerWithIdentifier:@"searchResults"];
  searchResultsViewController.dataLoader = _dataLoader;
  searchResultsViewController.localCachingClient = _localCachingClient;
  
  _searchController = [[UISearchController alloc] initWithSearchResultsController:searchResultsViewController];
  _searchController.searchResultsUpdater = searchResultsViewController;
  
  [self.view addSubview:_searchController.searchBar];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  
  CGRect searchBarFrame = CGRectMake(0, 0, self.view.frame.size.width, 56);
  searchBarFrame.origin.y = _embeddedView.frame.origin.y - searchBarFrame.size.height;
  _searchController.searchBar.frame = searchBarFrame;
}

- (MainViewController *)mainViewController {
  return nil;
}

@end
