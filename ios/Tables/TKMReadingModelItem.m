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

#import "TKMAudio.h"
#import "TKMReadingModelItem.h"

@interface TKMReadingModelCell : TKMAttributedModelCell<TKMAudioDelegate>
@end

@implementation TKMReadingModelItem

- (void)setAudio:(TKMAudio *)audio subjectID:(int)subjectID {
  _audio = audio;
  _audioSubjectID = subjectID;
}

- (Class)cellClass {
  return TKMReadingModelCell.class;
}

@end

@implementation TKMReadingModelCell {
  UIButton *_audioButton;
}

- (void)updateWithItem:(TKMReadingModelItem *)item {
  [super updateWithItem:item];
  
  if (item.audioSubjectID) {
    if (!self.rightButton) {
      self.rightButton = [[UIButton alloc] init];
      [self.rightButton setImage:[UIImage imageNamed:@"baseline_volume_up_black_24pt"]
                        forState:UIControlStateNormal];
      [self.rightButton addTarget:self
                           action:@selector(didTapButton)
                 forControlEvents:UIControlEventTouchUpInside];
      [self addSubview:self.rightButton];
    }
  } else {
    [self.rightButton removeFromSuperview];
    self.rightButton = nil;
  }
}

- (void)didTapButton {
  TKMReadingModelItem *item = (TKMReadingModelItem *)self.item;
  
  if (item.audio.currentState == TKMAudioPlaying) {
    [item.audio stopPlayback];
  } else {
    [item.audio playAudioForSubjectID:item.audioSubjectID delegate:self];
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
