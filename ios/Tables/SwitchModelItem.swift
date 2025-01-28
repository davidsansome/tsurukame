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

class SwitchModelItem: BasicModelItem {
  var isOn: Bool
  var switchHandler: ((UISwitch) -> Void)?

  init(style: UITableViewCell.CellStyle, title: String?, subtitle: String?, on: Bool,
       switchHandler: ((UISwitch) -> Void)? = nil) {
    isOn = on
    self.switchHandler = switchHandler
    super.init(style: style, title: title, subtitle: subtitle, accessoryType: .none,
               tapHandler: nil)
  }

  override var cellFactory: TableModelCellFactory {
    .fromFunction {
      SwitchModelCell(style: self.style, reuseIdentifier: self.cellReuseIdentifier)
    }
  }
}

class SwitchModelCell: BasicModelCell {
  @TypedModelItem var switchItem: SwitchModelItem

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    accessoryView = UISwitch(frame: .zero)
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var switchView: UISwitch {
    accessoryView as! UISwitch
  }

  override func update() {
    switchView.removeTarget(nil, action: nil, for: .valueChanged)

    super.update()

    switchView.isOn = switchItem.isOn
    if let switchHandler = switchItem.switchHandler {
      switchView.addAction(for: .valueChanged) { [unowned self] in
        switchHandler(self.switchView)
      }
    }
  }

  override func didSelect() {
    switchItem.isOn = !switchItem.isOn

    switchView.setOn(!switchView.isOn, animated: true)
    switchView.sendActions(for: .valueChanged)
  }
}
