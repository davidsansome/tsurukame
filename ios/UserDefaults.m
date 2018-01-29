#import "UserDefaults.h"

#define DEFINE_OBJECT(type, name, setterName) \
+ (type *)name { \
  return [[NSUserDefaults standardUserDefaults] stringForKey:@#name]; \
} \
+ (void)setterName:(type *)value { \
  [[NSUserDefaults standardUserDefaults] setObject:value forKey:@#name]; \
}

@implementation UserDefaults

DEFINE_OBJECT(NSString, userCookie, setUserCookie);
DEFINE_OBJECT(NSString, userApiToken, setUserApiToken);

@end
