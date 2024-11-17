// Copyright 2024 David Sansome
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

class ReviewQuickSettingsAnswersMenu: ReviewQuickSettingsTable {
  override func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "Answers & Marking")
    model.add(CheckmarkModelItem(style: .default, title: "Autoreveal answers",
                                 on: Settings.showAnswerImmediately) { on in
        Settings.showAnswerImmediately = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Reveal full answer",
                                 on: Settings.showFullAnswer) { on in
        Settings.showFullAnswer = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Exact match",
                                 on: Settings.exactMatch) { on in
        Settings.exactMatch = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Allow cheating",
                                 on: Settings.enableCheats) { on in
        Settings.enableCheats = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Allow skipping",
                                 on: Settings.allowSkippingReviews) { [weak self] on in
        Settings.allowSkippingReviews = on
        self?.delegate?.quickSettingsChanged()
      })

    self.model = model
    model.reloadTable()
  }
}
