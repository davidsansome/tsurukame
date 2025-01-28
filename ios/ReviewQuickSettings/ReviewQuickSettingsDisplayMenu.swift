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

class ReviewQuickSettingsDisplayMenu: ReviewQuickSettingsTable {
  override func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(BasicModelItem(style: .default, title: "Dark/light mode",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [unowned self] in
        self.delegate?.closeMenuAndPush(viewController: makeInterfaceStyleViewController())
      })
    model.add(CheckmarkModelItem(style: .default, title: "Show SRS level indicator",
                                 on: Settings.showSRSLevelIndicator) {
        [unowned self] on in
        Settings.showSRSLevelIndicator = on
        self.delegate?.quickSettingsChanged()
      })
    model.add(BasicModelItem(style: .default, title: "Fonts",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [unowned self] in
        let vc = StoryboardScene.SelectFonts.initialScene.instantiate()
        vc.setup(services: self.services)
        self.delegate?.closeMenuAndPush(viewController: vc)
      })
    model.add(BasicModelItem(style: .default, title: "Font size",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [unowned self] in
        self.delegate?.closeMenuAndPush(viewController: makeFontSizeViewController())
      })

    self.model = model
    model.reloadTable()
  }
}
