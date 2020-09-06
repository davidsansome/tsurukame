// Copyright 2020 David Sansome
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

private let kEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
private let kMinimumHeight: CGFloat = 44

@objc(TKMAttributedModelItem)
class AttributedModelItem: NSObject, TKMModelItem {
  let text: NSAttributedString

  init(text: NSAttributedString) {
    self.text = text
    super.init()
  }

  func cellClass() -> AnyClass! {
    AttributedModelCell.self
  }
}

class AttributedModelCell: TKMModelCell {
  var textView: UITextView!
  var rightButton: UIButton?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    selectionStyle = .none
    isUserInteractionEnabled = true

    textView = UITextView(frame: bounds)
    textView.isEditable = false
    textView.isScrollEnabled = false
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.backgroundColor = .clear

    contentView.addSubview(textView)
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var availableRect = CGRect(origin: .zero, size: size).inset(by: kEdgeInsets)
    let textViewSize = textView.sizeThatFits(availableRect.size)

    availableRect.size.height = max(kMinimumHeight,
                                    textViewSize.height + kEdgeInsets.top + kEdgeInsets.bottom)
    return availableRect.size
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    var availableRect = bounds.inset(by: kEdgeInsets)

    if let rightButton = rightButton {
      let buttonSize = rightButton.intrinsicContentSize
      rightButton.frame = CGRect(x: availableRect.maxX - buttonSize.width - kEdgeInsets.right,
                                 y: availableRect.origin.y - kEdgeInsets.top,
                                 width: buttonSize.width + kEdgeInsets.right * 2,
                                 height: availableRect.size.height + kEdgeInsets.top + kEdgeInsets
                                   .bottom)

      availableRect.size.width -= buttonSize.width + kEdgeInsets.right
    }

    // [UITextView sizeToFit] gives the wrong size for attributed strings that mix bold and normal
    // weight Japanese text.  We use [NSAttributedString boundingRectWithSize] which gives the correct
    // size.
    let text = textView.attributedText!
    let textViewSize = text.boundingRect(with: availableRect.size,
                                         options: .usesLineFragmentOrigin,
                                         context: nil).size

    // Center the text vertically.
    if textViewSize.height < availableRect.size.height {
      availableRect.origin.y += floor((availableRect.size.height - textViewSize.height) / 2)
      availableRect.size = textViewSize
    }

    textView.frame = availableRect
  }

  override func update(with baseItem: TKMModelItem!) {
    super.update(with: baseItem)

    let item = baseItem as! AttributedModelItem
    textView.attributedText = item.text
  }
}
