// Copyright 2023 David Sansome
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

  private func caluclateLayouts(_ availableRect: CGRect)
    -> (rightButtonFrame: CGRect?, exclusionPaths: [UIBezierPath], textHeight: CGFloat) {
    var rightButtonFrame: CGRect?
    var exclusionPaths = [UIBezierPath]()

    // If there's a right button, calculate its rectangle and add that as a text exclusion path.
    if let rightButton = rightButton {
      let buttonSize = rightButton.intrinsicContentSize
      rightButtonFrame = CGRect(x: availableRect.maxX - buttonSize.width - kEdgeInsets.left,
                                y: availableRect.origin.y - kEdgeInsets.top,
                                width: buttonSize.width + kEdgeInsets.right + kEdgeInsets.left,
                                height: buttonSize.height + kEdgeInsets.top + kEdgeInsets
                                  .bottom)
      exclusionPaths.append(UIBezierPath(rect: rightButtonFrame!))
    }

    // Calculate the height of the text. We can't just use UITextView.sizeThatFits because it gets
    // the wrong answer for CJK text. The order here matters, see
    // https://github.com/facebook/AsyncDisplayKit/issues/2894.
    let storage = NSTextStorage()
    let manager = NSLayoutManager()
    manager.usesFontLeading = false
    storage.addLayoutManager(manager)
    storage.setAttributedString(textView.attributedText)

    var size = availableRect.size
    size.height = CGFloat.greatestFiniteMagnitude

    let container = NSTextContainer(size: size)
    container.lineFragmentPadding = 0
    container.exclusionPaths = exclusionPaths
    manager.addTextContainer(container)
    manager.ensureLayout(for: container)

    let textHeight = manager.usedRect(for: container).height

    return (rightButtonFrame: rightButtonFrame, exclusionPaths: exclusionPaths,
            textHeight: textHeight)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let availableRect = CGRect(origin: .zero, size: size).inset(by: kEdgeInsets)
    let layout = caluclateLayouts(availableRect)

    return CGSize(width: availableRect.width, height: max(kMinimumHeight,
                                                          layout.textHeight + kEdgeInsets
                                                            .top + kEdgeInsets.bottom))
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    var availableRect = bounds.inset(by: kEdgeInsets)
    let layout = caluclateLayouts(availableRect)

    if let rightButton = rightButton, let rightButtonFrame = layout.rightButtonFrame {
      rightButton.frame = rightButtonFrame
    }
    textView.textContainer.exclusionPaths = layout.exclusionPaths

    let textViewSize = CGSize(width: availableRect.width, height: layout.textHeight)

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
