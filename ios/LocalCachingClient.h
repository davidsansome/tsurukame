#import <Foundation/Foundation.h>

#import "Client.h"
#import "Reachability.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName kLocalCachingClientBusyChangedNotification;
extern NSNotificationName kLocalCachingClientBusyChangedNotification;

@protocol LocalCachingClientDelegate

- (void)localCachingClientDidReportError:(NSError *)error;

@end

@interface LocalCachingClient : NSObject

@property(nonatomic, getter=isBusy, readonly) bool busy;
@property(nonatomic, readonly) NSDate *lastUpdated;
@property(nonatomic) id<LocalCachingClientDelegate> delegate;

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)update;

- (void)getAllAssignments:(AssignmentHandler)handler;
- (WKStudyMaterials * _Nullable)getStudyMaterialForID:(int)subjectID;
- (WKUser * _Nullable)getUserInfo;

- (void)sendProgress:(NSArray<WKProgress *> *)progress
             handler:(ProgressHandler _Nullable)handler;
- (void)updateStudyMaterial:(WKStudyMaterials *)material
                    handler:(UpdateStudyMaterialHandler _Nullable)handler;

@end

NS_ASSUME_NONNULL_END
