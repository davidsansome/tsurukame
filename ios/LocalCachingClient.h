#import <Foundation/Foundation.h>

#import "Client.h"
#import "Reachability.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalCachingClient : NSObject

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)update;

- (void)getAllAssignments:(AssignmentHandler)handler;
- (void)sendProgress:(NSArray<WKProgress *> *)progress
             handler:(ProgressHandler)handler;

@end

NS_ASSUME_NONNULL_END
