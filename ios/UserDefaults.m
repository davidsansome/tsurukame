#import "UserDefaults.h"

#define DEFINE_OBJECT(type, name, setterName) \
+ (type *)name { \
  return [[NSUserDefaults standardUserDefaults] stringForKey:@#name]; \
} \
+ (void)setterName:(type *)value { \
  [[NSUserDefaults standardUserDefaults] setObject:value forKey:@#name]; \
}

#define DEFINE_BOOL(name, setterName, defaultValue) \
+ (BOOL)name { \
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults]; \
  if ([ud objectForKey:@#name] == nil) { \
    return defaultValue; \
  } \
  return [ud boolForKey:@#name]; \
} \
+ (void)setterName:(BOOL)value { \
  [[NSUserDefaults standardUserDefaults] setBool:value forKey:@#name]; \
}

@implementation UserDefaults

DEFINE_OBJECT(NSString, userCookie, setUserCookie);
DEFINE_OBJECT(NSString, userEmailAddress, setUserEmailAddress);
DEFINE_OBJECT(NSString, userApiToken, setUserApiToken);

DEFINE_BOOL(animateParticleExplosion, setAnimateParticleExplosion, YES);
DEFINE_BOOL(animateLevelUpPopup, setAnimateLevelUpPopup, YES);
DEFINE_BOOL(animatePlusOne, setAnimatePlusOne, YES);

DEFINE_BOOL(enableCheats, setEnableCheats, YES);

@end
