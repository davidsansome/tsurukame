// Copyright 2025 David Sansome
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

class ReadingModelItem: AttributedModelItem {
  var audio: Audio?
  var audioSubjectID: Int64 = 0

  weak var audioDelegate: AudioDelegate?

  override init(text: NSAttributedString) {
    super.init(text: text)
  }

  func setAudio(_ audio: Audio, subjectID: Int64) {
    self.audio = audio
    audioSubjectID = subjectID
    rightButtonImage = Asset.baselineVolumeUpBlack24pt.image
    rightButtonCallback = { [unowned self] (_: AttributedModelCell) in
      self.playAudio()
    }
  }

  override var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: ReadingModelCell.self)
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
  @TypedModelItem var readingItem: ReadingModelItem

  override func update() {
    super.update()
    if readingItem.audioSubjectID != 0 {
      readingItem.audioDelegate = self
    } else {
      readingItem.audioDelegate = nil
    }
  }

  func audioPlaybackStateChanged(state: Audio.PlaybackState) {
    switch state {
    case .loading:
      rightButton?.isEnabled = false
    case .playing:
      rightButton?.isEnabled = true
      rightButton?.setImage(Asset.baselineStopBlack24pt.image, for: .normal)
    case .finished:
      rightButton?.isEnabled = true
      rightButton?.setImage(Asset.baselineVolumeUpBlack24pt.image, for: .normal)
    }
  }
}
