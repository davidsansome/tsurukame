#import <Foundation/Foundation.h>

#import "Client.h"
#import "Reachability.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kLocalCachingClientBusyChangedNotification;

@protocol LocalCachingClientDelegate

- (void)localCachingClientDidReportError:(NSError *)error;

@end

@interface LocalCachingClient : NSObject

// Whether we're currently making network requests.  A kLocalCachingClientBusyChangedNotification
// notification is sent when this changes.
@property(nonatomic, getter=isBusy, readonly) bool busy;

@property(nonatomic) id<LocalCachingClientDelegate> delegate;

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Sends pending review progress and study material updates, fetches updates.
// Returns immediately but sets busy=false when it's done.
- (void)update;

// Getters: query the database and return data immediately, without making network requests.
- (NSArray<WKAssignment *> *)getAllAssignments;
- (WKStudyMaterials * _Nullable)getStudyMaterialForID:(int)subjectID;
- (WKUser * _Nullable)getUserInfo;

// Setters: save the data to the database and return immediately, make network requests in the
// background.
- (void)sendProgress:(NSArray<WKProgress *> *)progress;
- (void)updateStudyMaterial:(WKStudyMaterials *)material;

@end

NS_ASSUME_NONNULL_END
