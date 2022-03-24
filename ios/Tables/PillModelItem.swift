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

class PillModelItem: NSObject, TKMModelItem {
  let text: String
  let fontSize: CGFloat
  let callback: () -> Void

  init(text: String, fontSize: CGFloat, callback: @escaping () -> Void) {
    self.text = text
    self.fontSize = fontSize
    self.callback = callback
  }

  func cellNibName() -> String! {
    "PillModelItem"
  }
}

class PillModelCell: TKMModelCell {
  @IBOutlet var button: UIButton!
  @IBOutlet var leftLineHeight: NSLayoutConstraint!
  @IBOutlet var rightLineHeight: NSLayoutConstraint!

  override func layoutSubviews() {
    super.layoutSubviews()

    // Set the left line, right line, and button border width to be exactly 1 pixel (scaled by
    // screen scale), to match the default table cell borders.
    let borderWidth = 1.0 / UIScreen.main.scale
    leftLineHeight.constant = borderWidth
    rightLineHeight.constant = borderWidth

    button.layer.backgroundColor = TKMStyle.Color.cellBackground.cgColor
    button.layer.borderWidth = borderWidth
    button.layer.borderColor = TKMStyle.Color.separator.cgColor
    button.layer.cornerRadius = button.frame.size.height * 0.5
    button.clipsToBounds = true
    button.layer.masksToBounds = true
    button.layer.rasterizationScale = UIScreen.main.scale
    button.layer.shouldRasterize = true
  }

  override func update(with item: TKMModelItem!) {
    super.update(with: item)
    let item = item as! PillModelItem

    let font = UIFont.systemFont(ofSize: item.fontSize)
    let title = NSAttributedString(string: item.text, attributes: [
      .font: font,
      .foregroundColor: button.tintColor!,
    ])
    button.setAttributedTitle(title, for: .normal)
  }

  @IBAction func buttonPressed(_: Any) {
    let item = self.item as! PillModelItem
    item.callback()
  }

  override func addSubview(_ view: UIView) {
    // Prevent the default table cell separators from being added to this cell.
    if !view.isKind(of: NSClassFromString("_UITableViewCellSeparatorView")!) {
      super.addSubview(view)
    }
  }
}
