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

class ListSeparatorItem: TableModelItem {
  var label: String

  init(label: String) {
    self.label = label
  }

  var cellFactory: TableModelCellFactory {
    .fromInterfaceBuilder(nibName: "ListSeparatorItem")
  }

  var rowHeight: CGFloat? {
    UIFontMetrics.default.scaledValue(for: 22.0)
  }
}

class ListSeparatorCell: TableModelCell {
  @TypedModelItem var item: ListSeparatorItem

  @IBOutlet var label: UILabel!

  override func update() {
    // A small tracked-capitals label on the card, like the section headers.
    backgroundColor = TKMStyle.Color.cellBackground
    contentView.backgroundColor = .clear
    let boldFont = UIFont.systemFont(ofSize: 11.0, weight: .bold)
    label.attributedText = NSAttributedString(string: item.label.uppercased(), attributes: [
      .font: UIFontMetrics(forTextStyle: .footnote).scaledFont(for: boldFont),
      .foregroundColor: TKMStyle.Color.grey33,
      .kern: 1.4,
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    superview?.bringSubviewToFront(self)
  }
}
