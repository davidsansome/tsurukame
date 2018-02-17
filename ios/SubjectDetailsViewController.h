#import <UIKit/UIKit.h>

#import "DataLoader.h"
#import "LocalCachingClient.h"
#import "SubjectDetailsView.h"
#import "proto/Wanikani.pbobjc.h"

@interface SubjectDetailsViewController : UIViewController

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) LocalCachingClient *localCachingClient;
@property (nonatomic) WKSubject *subject;

// If this is set to true before the view is loaded, the back button will be hidden.
@property (nonatomic) bool hideBackButton;

// The index of this subject in some other collection.  Unused, for convenience only.
@property (nonatomic) NSInteger index;

@end
