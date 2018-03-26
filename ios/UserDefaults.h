#import <Foundation/Foundation.h>

#define DECLARE_OBJECT(type, name) \
@property(class, nonatomic, copy) type *name;

#define DECLARE_BOOL(name) \
@property(class, nonatomic) BOOL name;

@interface UserDefaults : NSObject

DECLARE_OBJECT(NSString, userCookie);
DECLARE_OBJECT(NSString, userEmailAddress);
DECLARE_OBJECT(NSString, userApiToken);

DECLARE_BOOL(animateParticleExplosion);
DECLARE_BOOL(animateLevelUpPopup);
DECLARE_BOOL(animatePlusOne);

DECLARE_BOOL(enableCheats);

@end
