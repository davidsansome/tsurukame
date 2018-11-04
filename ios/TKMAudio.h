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

@class Reachability;

typedef enum TKMAudioPlaybackState {
  TKMAudioLoading,
  TKMAudioPlaying,
  TKMAudioFinished,
} TKMAudioPlaybackState;

@protocol TKMAudioDelegate<NSObject>

- (void)audioPlaybackStateChanged:(TKMAudioPlaybackState)state;

@end

@interface TKMAudio : NSObject

@property(nonatomic, readonly) TKMAudioPlaybackState currentState;

+ (NSString *)cacheDirectoryPath;

- (instancetype)initWithReachability:(Reachability *)reachability
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)playAudioForSubjectID:(int)subjectID
                     delegate:(nullable id<TKMAudioDelegate>)delegate;
- (void)stopPlayback;

@end

NS_ASSUME_NONNULL_END
