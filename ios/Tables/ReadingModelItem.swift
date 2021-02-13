// Copyright 2021 David Sansome
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

import Foundation

@objc(TKMReadingModelItem)
@objcMembers
class ReadingModelItem: AttributedModelItem {
  var audio: Audio?
  var audioSubjectID: Int32 = 0

  weak var audioDelegate: AudioDelegate?

  override init(text: NSAttributedString) {
    super.init(text: text)
  }

  func setAudio(_ audio: Audio, subjectID: Int32) {
    self.audio = audio
    audioSubjectID = subjectID
  }

  override func cellClass() -> AnyClass! {
    ReadingModelCell.self
  }

  func playAudio() {
    if let audio = audio {
      if audio.currentState == .playing {
        audio.stopPlayback()
      } else {
        audio.play(subjectID: audioSubjectID, delegate: audioDelegate)
      }
    }
  }
}

class ReadingModelCell: AttributedModelCell, AudioDelegate {
  override func update(with baseItem: TKMModelItem!) {
    super.update(with: baseItem)
    let item = baseItem as! ReadingModelItem

    if item.audioSubjectID != 0 {
      if rightButton == nil {
        rightButton = UIButton()
        rightButton!
          .addTarget(item, action: #selector(ReadingModelItem.playAudio), for: .touchUpInside)
        addSubview(rightButton!)
      }
      rightButton!.setImage(UIImage(named: "baseline_volume_up_black_24pt"), for: .normal)
      item.audioDelegate = self
    } else {
      rightButton?.removeFromSuperview()
      rightButton = nil
      item.audioDelegate = nil
    }
  }

  func audioPlaybackStateChanged(state: Audio.PlaybackState) {
    switch state {
    case .loading:
      rightButton?.isEnabled = false
    case .playing:
      rightButton?.isEnabled = true
      rightButton?.setImage(UIImage(named: "baseline_stop_black_24pt"), for: .normal)
    case .finished:
      rightButton?.isEnabled = true
      rightButton?.setImage(UIImage(named: "baseline_volume_up_black_24pt"), for: .normal)
    }
  }
}
