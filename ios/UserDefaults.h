#import <Foundation/Foundation.h>

#define DECLARE_OBJECT(type, name) \
@property(class, nonatomic, copy) type *name;

@interface UserDefaults : NSObject

DECLARE_OBJECT(NSString, userCookie);
DECLARE_OBJECT(NSString, userApiToken);

@end
