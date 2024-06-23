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

class BasicModelItem: TableModelItem {
  let style: UITableViewCell.CellStyle

  var title: String?
  var titleFont: UIFont?
  var numberOfTitleLines: Int = 0

  var subtitle: String?
  var subtitleFont: UIFont?
  var subtitleTextColor: UIColor?
  var attributedSubtitle: NSAttributedString?
  var numberOfSubtitleLines: Int = 0

  var accessoryType: UITableViewCell.AccessoryType = .none

  var image: UIImage?

  var tapHandler: (() -> Void)?

  var textColor: UIColor?
  var imageTintColor: UIColor?

  var isEnabled = true

  weak var cell: BasicModelCell?

  init(style: UITableViewCell.CellStyle, title: String?, subtitle: String? = nil,
       accessoryType: UITableViewCell.AccessoryType = .none, tapHandler: (() -> Void)? = nil) {
    self.style = style
    self.title = title
    self.subtitle = subtitle
    self.accessoryType = accessoryType
    self.tapHandler = tapHandler

    titleFont = UIFont.preferredFont(forTextStyle: .body)
    subtitleFont = UIFont.preferredFont(forTextStyle: .subheadline)
  }

  var cellReuseIdentifier: String {
    [
      String(describing: self.self),
      String(style.rawValue),
    ].joined(separator: "/")
  }

  var cellFactory: TableModelCellFactory {
    .fromFunction {
      BasicModelCell(style: self.style, reuseIdentifier: self.cellReuseIdentifier)
    }
  }
}

class BasicModelCell: TableModelCell {
  @TypedModelItem var item: BasicModelItem

  override func update() {
    selectionStyle = .none

    textLabel?.text = item.title
    textLabel?.font = item.titleFont
    textLabel?.textColor = item.textColor
    textLabel?.numberOfLines = item.numberOfTitleLines

    detailTextLabel?.font = item.subtitleFont
    detailTextLabel?.textColor = item.subtitleTextColor
    detailTextLabel?.numberOfLines = item.numberOfSubtitleLines
    if let attributedSubtitle = item.attributedSubtitle {
      detailTextLabel?.attributedText = attributedSubtitle
    } else {
      detailTextLabel?.text = item.subtitle
    }

    accessoryType = item.accessoryType

    imageView?.image = item.image
    imageView?.tintColor = item.imageTintColor

    isUserInteractionEnabled = item.isEnabled
    textLabel?.isEnabled = item.isEnabled
    detailTextLabel?.isEnabled = item.isEnabled

    item.cell = self
  }

  override func didSelect() {
    if let tapHandler = item.tapHandler {
      tapHandler()
    }
  }
}
