#import <Foundation/Foundation.h>

#import "Client.h"
#import "Reachability.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kLocalCachingClientAvailableItemsChangedNotification;
extern NSNotificationName kLocalCachingClientPendingItemsChangedNotification;

typedef void (^CompletionHandler)(void);

@interface LocalCachingClient : NSObject

@property(nonatomic, readonly) int availableLessonCount;
@property(nonatomic, readonly) int availableReviewCount;
@property(nonatomic, readonly) NSArray<NSNumber *> *upcomingReviews;
@property(nonatomic, readonly) int pendingProgress;
@property(nonatomic, readonly) int pendingStudyMaterials;

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Sends pending review progress and study material updates, fetches updates.  The completion
// handler is always executed on the main queue.
- (void)sync:(CompletionHandler _Nullable)completionHandler;

// Getters: query the database and return data immediately, without making network requests.
- (NSArray<WKAssignment *> *)getAllAssignments;
- (WKStudyMaterials * _Nullable)getStudyMaterialForID:(int)subjectID;
- (WKUser * _Nullable)getUserInfo;

// Setters: save the data to the database and return immediately, make network requests in the
// background.
- (void)sendProgress:(NSArray<WKProgress *> *)progress;
- (void)updateStudyMaterial:(WKStudyMaterials *)material;

// Delete everything: use when a user logs out.
- (void)clearAllData;

@end

NS_ASSUME_NONNULL_END
