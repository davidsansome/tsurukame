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

class CheckmarkModelItem: BasicModelItem {
  var isOn: Bool
  var switchHandler: ((Bool) -> Void)?

  init(style: UITableViewCell.CellStyle, title: String?, subtitle: String? = nil, on: Bool,
       switchHandler: ((Bool) -> Void)? = nil) {
    isOn = on
    self.switchHandler = switchHandler
    super.init(style: style, title: title, subtitle: subtitle, accessoryType: .none,
               tapHandler: nil)
  }

  override var cellFactory: TableModelCellFactory {
    .fromFunction {
      CheckmarkModelCell(style: self.style, reuseIdentifier: self.cellReuseIdentifier)
    }
  }
}

class CheckmarkModelCell: BasicModelCell {
  @TypedModelItem var checkmarkItem: CheckmarkModelItem

  private static let kTapAnimationWhiteness: CGFloat = 0.5
  private static let kTapAnimationDuration: TimeInterval = 0.4

  override func update() {
    super.update()
    accessoryType = checkmarkItem.isOn ? .checkmark : .none
  }

  override func didSelect() {
    checkmarkItem.isOn = !checkmarkItem.isOn

    if let switchHandler = checkmarkItem.switchHandler {
      switchHandler(checkmarkItem.isOn)
    }
    accessoryType = checkmarkItem.isOn ? .checkmark : .none

    backgroundColor = UIColor(white: CheckmarkModelCell.kTapAnimationWhiteness, alpha: 1.0)
    UIView.animate(withDuration: CheckmarkModelCell.kTapAnimationDuration, delay: 0.0,
                   options: .curveEaseIn,
                   animations: {
                     self.backgroundColor = .clear
                   }, completion: nil)
  }
}
