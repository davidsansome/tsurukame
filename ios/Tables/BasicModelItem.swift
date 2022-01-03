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

@objc(TKMBasicModelItem)
@objcMembers
class BasicModelItem: NSObject, TKMModelItem {
  let style: UITableViewCell.CellStyle

  var title: String?
  var titleFont: UIFont?
  var numberOfTitleLines: Int = 1

  var subtitle: String?
  var subtitleFont: UIFont?
  var subtitleTextColor: UIColor?
  var attributedSubtitle: NSAttributedString?
  var numberOfSubtitleLines: Int = 1

  var accessoryType: UITableViewCell.AccessoryType = .none

  var image: UIImage?

  var target: NSObject?
  var action: Selector?
  var tapHandler: (() -> Void)?

  var textColor: UIColor?
  var imageTintColor: UIColor?

  var isEnabled = true

  weak var cell: BasicModelCell?

  init(style: UITableViewCell.CellStyle, title: String?, subtitle: String? = nil,
       accessoryType: UITableViewCell.AccessoryType = .none, target: NSObject? = nil,
       action: Selector? = nil, tapHandler: (() -> Void)? = nil) {
    self.style = style
    self.title = title
    self.subtitle = subtitle
    self.accessoryType = accessoryType
    self.target = target
    self.action = action
    self.tapHandler = tapHandler

    if style == .subtitle {
      subtitleFont = UIFont.preferredFont(forTextStyle: .caption2)
    }
  }

  // For objective-C compatibility only.
  convenience init(style: UITableViewCell.CellStyle, title: String?, subtitle: String?,
                   accessoryType: UITableViewCell.AccessoryType, target: NSObject?,
                   action: Selector?) {
    self.init(style: style, title: title, subtitle: subtitle, accessoryType: accessoryType,
              target: target, action: action, tapHandler: nil)
  }

  func cellClass() -> AnyClass! {
    BasicModelCell.self
  }

  func cellReuseIdentifier() -> String! {
    [
      String(describing: cellClass()!),
      String(style.rawValue),
    ].joined(separator: "/")
  }

  func createCell() -> TKMModelCell! {
    BasicModelCell(style: style, reuseIdentifier: cellReuseIdentifier())
  }
}

class BasicModelCell: TKMModelCell {
  override func update(with baseItem: TKMModelItem!) {
    super.update(with: baseItem)
    let item = baseItem as! BasicModelItem

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
    let item = self.item as! BasicModelItem
    if let tapHandler = item.tapHandler {
      tapHandler()
    } else {
      TKMSafePerformSelector(item.target, item.action, item)
    }
  }
}
