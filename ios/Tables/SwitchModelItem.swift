// Copyright David Sansome
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

private let kSwitchActionIdentifier = UIAction.Identifier("SwitchModelCell.valueChanged")

class SwitchModelItem: BasicModelItem {
  var isOn: Bool
  var switchHandler: ((UISwitch) -> Void)?

  // Whether tapping anywhere on the row flips the switch. Turn this off for switches that are
  // costly to flip by accident, so only the switch itself responds.
  var togglesOnRowTap = true

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
    // Keep the item in step with the switch, so a reused cell shows the right state.
    // A fixed identifier means this replaces the action added for the cell's previous item.
    switchView.addAction(UIAction(identifier: kSwitchActionIdentifier) { [unowned self] _ in
      self.switchItem.isOn = self.switchView.isOn
      self.switchItem.switchHandler?(self.switchView)
    }, for: .valueChanged)
  }

  override func didSelect() {
    guard switchItem.togglesOnRowTap else { return }

    switchView.setOn(!switchView.isOn, animated: true)
    switchView.sendActions(for: .valueChanged)
  }
}
