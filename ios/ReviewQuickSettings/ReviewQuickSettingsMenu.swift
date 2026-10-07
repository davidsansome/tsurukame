// Copyright 2026 David Sansome
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

protocol ReviewQuickSettingsMenuDelegate: AnyObject {
  func quickSettingsChanged()
  func closeMenuAndPush(viewController: UIViewController)
}

class ReviewQuickSettingsMenu: ReviewQuickSettingsTable {
  override func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "Quick Settings")
    model.add(BasicModelItem(style: .default, title: "Display",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [unowned self] in
        self.navigationController?
          .pushViewController(ReviewQuickSettingsDisplayMenu(services: self.services,
                                                             delegate: self
                                                               .delegate), animated: true)
      })
    model.add(BasicModelItem(style: .default, title: "Answers & Marking",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [unowned self] in
        self.navigationController?
          .pushViewController(ReviewQuickSettingsAnswersMenu(services: self.services,
                                                             delegate: self
                                                               .delegate), animated: true)
      })
    model.add(BasicModelItem(style: .default, title: "Audio",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [unowned self] in
        self.navigationController?
          .pushViewController(ReviewQuickSettingsAudioMenu(services: self.services,
                                                           delegate: self
                                                             .delegate), animated: true)
      })

    self.model = model
    model.reloadTable()
  }
}
