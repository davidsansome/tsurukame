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

@objc(TKMCheckmarkModelItem)
@objcMembers
class CheckmarkModelItem: BasicModelItem {
  @objc(on) var isOn: Bool

  init(style: UITableViewCell.CellStyle, title: String?, subtitle: String?, on: Bool,
       target: NSObject?, action: Selector?) {
    isOn = on
    super.init(style: style, title: title, subtitle: subtitle, accessoryType: .none, target: target,
               action: action)
  }

  override func cellClass() -> AnyClass! {
    CheckmarkModelCell.self
  }

  override func createCell() -> TKMModelCell! {
    CheckmarkModelCell(style: style, reuseIdentifier: cellReuseIdentifier())
  }
}

class CheckmarkModelCell: BasicModelCell {
  private static let kTapAnimationWhiteness: CGFloat = 0.5
  private static let kTapAnimationDuration: TimeInterval = 0.4

  override func update(with baseItem: TKMModelItem) {
    super.update(with: baseItem)
    let item = baseItem as! CheckmarkModelItem

    accessoryType = item.isOn ? .checkmark : .none
  }

  override func didSelect() {
    let item = self.item as! CheckmarkModelItem
    item.isOn = !item.isOn

    TKMSafePerformSelector(item.target, item.action, item)
    accessoryType = item.isOn ? .checkmark : .none

    backgroundColor = UIColor(white: CheckmarkModelCell.kTapAnimationWhiteness, alpha: 1.0)
    UIView.animate(withDuration: CheckmarkModelCell.kTapAnimationDuration, delay: 0.0,
                   options: .curveEaseIn,
                   animations: {
                     self.backgroundColor = .clear
                   }, completion: nil)
  }
}
