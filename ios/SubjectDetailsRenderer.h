#import <Foundation/Foundation.h>

#import "DataLoader.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSubjectDetailsRenderer : NSObject

- (instancetype)initWithDataLoader:(DataLoader *)dataLoader NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSString *)renderSubjectDetails:(WKSubject *)subject;

@end

NS_ASSUME_NONNULL_END

