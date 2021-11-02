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

private let kEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
private let kMinimumHeight: CGFloat = 44

@objc(TKMAttributedModelItem)
class AttributedModelItem: NSObject, TKMModelItem {
  var text: NSAttributedString

  var rightButtonImage: UIImage?
  var rightButtonCallback: ((_ cell: AttributedModelCell) -> Void)?

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

  private func rightButtonFrame(_ availableRect: CGRect) -> CGRect? {
    guard let rightButton = rightButton else {
      return nil
    }
    let buttonSize = rightButton.intrinsicContentSize
    return CGRect(x: availableRect.maxX - buttonSize.width - kEdgeInsets.right,
                  y: availableRect.origin.y - kEdgeInsets.top,
                  width: buttonSize.width + kEdgeInsets.right * 2,
                  height: buttonSize.height + kEdgeInsets.top + kEdgeInsets
                    .bottom)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var availableRect = CGRect(origin: .zero, size: size).inset(by: kEdgeInsets)
    var exclusionPaths = [UIBezierPath]()
    if let rightButtonFrame = rightButtonFrame(availableRect) {
      exclusionPaths.append(UIBezierPath(rect: rightButtonFrame))
    }
    textView.textContainer.exclusionPaths = exclusionPaths

    let textViewSize = textView.sizeThatFits(availableRect.size)
    availableRect.size.height = max(kMinimumHeight,
                                    textViewSize.height + kEdgeInsets.top + kEdgeInsets.bottom)
    return availableRect.size
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    var availableRect = bounds.inset(by: kEdgeInsets)
    var exclusionPaths = [UIBezierPath]()
    if let rightButton = rightButton, let rightButtonFrame = rightButtonFrame(availableRect) {
      rightButton.frame = rightButtonFrame
      exclusionPaths.append(UIBezierPath(rect: rightButtonFrame))
    }
    textView.textContainer.exclusionPaths = exclusionPaths

    var textViewSize = textView.sizeThatFits(availableRect.size)
    textViewSize.width = availableRect.size.width

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

    if let rightButtonImage = item.rightButtonImage {
      if rightButton == nil {
        rightButton = UIButton()
        rightButton!
          .addTarget(self, action: #selector(AttributedModelCell.didTapRightButton),
                     for: .touchUpInside)
        addSubview(rightButton!)
      }
      rightButton!.setImage(rightButtonImage, for: .normal)
    } else {
      removeRightButton()
    }
  }

  func removeRightButton() {
    let item = self.item as! AttributedModelItem
    item.rightButtonImage = nil

    rightButton?.removeFromSuperview()
    rightButton = nil
    textView.textContainer.exclusionPaths = []
  }

  @objc func didTapRightButton() {
    let item = self.item as! AttributedModelItem
    item.rightButtonCallback?(self)
  }
}
