// Copyright 2018 David Sansome
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
