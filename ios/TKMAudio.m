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

#import "Reachability.h"
#import "TKMAudio.h"

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

static NSString *const kURLPattern = @"https://tsurukame.app/audio/%d.mp3";

@implementation TKMAudio {
  Reachability *_reachability;
  AVPlayer *_player;
  __weak id<TKMAudioDelegate> _delegate;
}

- (instancetype)initWithReachability:(Reachability *)reachability {
  self = [super init];
  if (self) {
    _reachability = reachability;
    _currentState = TKMAudioFinished;
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(itemFinishedPlaying:)
               name:AVPlayerItemDidPlayToEndTimeNotification
             object:nil];
  }
  return self;
}

- (void)setCurrentState:(TKMAudioPlaybackState)state {
  if (state != _currentState) {
    _currentState = state;
    [_delegate audioPlaybackStateChanged:_currentState];
  }
}

- (void)playAudioForSubjectID:(int)subjectID
                     delegate:(nullable id<TKMAudioDelegate>)delegate {
  if (!_reachability.isReachable) {
    [self showOfflineDialog];
    return;
  }
  
  [self setCurrentState:TKMAudioFinished];
  _delegate = delegate;
  
  NSString *urlString = [NSString stringWithFormat:kURLPattern, subjectID];
  
  if (!_player || _player.status == AVPlayerStatusFailed) {
    _player = [[AVPlayer alloc] init];
    [_player addObserver:self forKeyPath:@"currentItem.status" options:0 context:nil];
  }
  
  AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:urlString]];
  [_player replaceCurrentItemWithPlayerItem:item];
  [_player play];
}

- (void)stopPlayback {
  [_player pause];
  [self setCurrentState:TKMAudioFinished];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
  if ([keyPath isEqual:@"currentItem.status"]) {
    switch (_player.currentItem.status) {
      case AVPlayerItemStatusFailed:
        [self showErrorDialog:_player.currentItem.error];
        [self setCurrentState:TKMAudioFinished];
        break;
        
      case AVPlayerItemStatusUnknown:
        [self setCurrentState:TKMAudioLoading];
        break;
        
      case AVPlayerItemStatusReadyToPlay:
        [self setCurrentState:TKMAudioPlaying];
        break;
    }
  }
}

- (void)showErrorDialog:(NSError *)error {
  AVURLAsset *asset = (AVURLAsset *)_player.currentItem.asset;
  NSString *message = [NSString stringWithFormat:@"%@\nURL: %@",
                       error.localizedFailureReason, asset.URL];
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:error.localizedDescription
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * action) {}];
  [alert addAction:action];
  
  UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;
  [vc presentViewController:alert animated:YES completion:nil];
}

- (void)showOfflineDialog {
  NSString *title = @"Audio not available offline";
  NSString *message = @"Download audio in Settings when you're back online";
  
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * action) {}];
  [alert addAction:action];
  
  UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;
  [vc presentViewController:alert animated:YES completion:nil];
}

- (void)itemFinishedPlaying:(NSNotification *)notification {
  [self setCurrentState:TKMAudioFinished];
}

@end
