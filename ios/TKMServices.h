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

NS_ASSUME_NONNULL_BEGIN

@class DataLoader;
@class LocalCachingClient;
@class Reachability;
@class TKMAudio;
@class TKMFontLoader;

@interface TKMServices : NSObject

@property(nonatomic, readonly) TKMAudio *audio;
@property(nonatomic, readonly) DataLoader *dataLoader;
@property(nonatomic, readonly) TKMFontLoader *fontLoader;
@property(nonatomic, readonly, nullable) LocalCachingClient *localCachingClient;
@property(nonatomic, readonly) Reachability *reachability;

@end

NS_ASSUME_NONNULL_END
