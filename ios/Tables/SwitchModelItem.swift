// Copyright 2022 David Sansome
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

@objc(TKMSwitchModelItem)
class SwitchModelItem: BasicModelItem {
  var isOn: Bool
  var switchHandler: ((Bool) -> Void)?

  init(style: UITableViewCell.CellStyle, title: String?, subtitle: String?, on: Bool,
       target: NSObject? = nil, action: Selector? = nil, switchHandler: ((Bool) -> Void)? = nil) {
    isOn = on
    self.switchHandler = switchHandler
    super.init(style: style, title: title, subtitle: subtitle, accessoryType: .none, target: target,
               action: action, tapHandler: nil)
  }

  override func cellClass() -> AnyClass! {
    SwitchModelCell.self
  }

  override func createCell() -> TKMModelCell! {
    SwitchModelCell(style: style, reuseIdentifier: cellReuseIdentifier())
  }
}

class SwitchModelCell: BasicModelCell {
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

  override func update(with baseItem: TKMModelItem) {
    switchView.removeTarget(nil, action: nil, for: .valueChanged)

    super.update(with: baseItem)
    let item = baseItem as! SwitchModelItem

    switchView.isOn = item.isOn
    if let switchHandler = item.switchHandler {
      switchView.addAction(for: .valueChanged) { [unowned self] in
        switchHandler(self.switchView.isOn)
      }
    } else if let target = item.target, let action = item.action {
      switchView.addTarget(target, action: action, for: .valueChanged)
    }
  }

  override func didSelect() {
    let item = self.item as! SwitchModelItem
    item.isOn = !item.isOn

    switchView.setOn(!switchView.isOn, animated: true)
    switchView.sendActions(for: .valueChanged)
  }
}
