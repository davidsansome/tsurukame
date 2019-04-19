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

#import "TKMReadingModelItem.h"
#import "TKMAudio.h"

@interface TKMReadingModelCell : TKMAttributedModelCell <TKMAudioDelegate>
@end

@implementation TKMReadingModelItem

- (void)setAudio:(TKMAudio *)audio subjectID:(int)subjectID {
  _audio = audio;
  _audioSubjectID = subjectID;
}

- (Class)cellClass {
  return TKMReadingModelCell.class;
}

- (void)playAudio {
  if (_audio.currentState == TKMAudioPlaying) {
    [_audio stopPlayback];
  } else {
    [_audio playAudioForSubjectID:_audioSubjectID delegate:_audioDelegate];
  }
}

@end

@implementation TKMReadingModelCell

- (void)updateWithItem:(TKMReadingModelItem *)item {
  [super updateWithItem:item];

  if (item.audioSubjectID) {
    if (!self.rightButton) {
      self.rightButton = [[UIButton alloc] init];
      [self.rightButton addTarget:item
                           action:@selector(playAudio)
                 forControlEvents:UIControlEventTouchUpInside];
      [self addSubview:self.rightButton];
    }
    [self.rightButton setImage:[UIImage imageNamed:@"baseline_volume_up_black_24pt"]
                      forState:UIControlStateNormal];
    item.audioDelegate = self;
  } else {
    [self.rightButton removeFromSuperview];
    self.rightButton = nil;
    item.audioDelegate = nil;
  }
}

- (void)audioPlaybackStateChanged:(TKMAudioPlaybackState)state {
  switch (state) {
    case TKMAudioLoading:
      self.rightButton.enabled = NO;
      break;
    case TKMAudioPlaying:
      self.rightButton.enabled = YES;
      [self.rightButton setImage:[UIImage imageNamed:@"baseline_stop_black_24pt"]
                        forState:UIControlStateNormal];
      break;
    case TKMAudioFinished:
      self.rightButton.enabled = YES;
      [self.rightButton setImage:[UIImage imageNamed:@"baseline_volume_up_black_24pt"]
                        forState:UIControlStateNormal];
      break;
  }
}

@end
