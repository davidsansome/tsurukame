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
import UIKit

class ReviewQuickSettingsAudioMenu: ReviewQuickSettingsTable {
  override func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "Audio")
    model.add(CheckmarkModelItem(style: .default, title: "Autoplay audio",
                                 on: Settings.playAudioAutomatically) { on in
        Settings.playAudioAutomatically = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Interrupt background audio",
                                 on: Settings.playAudioAutomatically) { on in
        Settings.interruptBackgroundAudio = on
      })

    self.model = model
    model.reloadTable()
  }
}
