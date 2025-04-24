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

private let kEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
private let kMinimumHeight: CGFloat = 44

class AttributedModelItem: NSObject, TableModelItem {
  var text: NSAttributedString

  var rightButtonImage: UIImage?
  var rightButtonCallback: ((_ cell: AttributedModelCell) -> Void)?

  init(text: NSAttributedString) {
    self.text = text
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: AttributedModelCell.self)
  }
}

class AttributedModelCell: TableModelCell {
  @TypedModelItem var item: AttributedModelItem

  var textView: UITextView!
  var rightButton: UIButton?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    selectionStyle = .none
    isUserInteractionEnabled = true

    if #available(iOS 16.0, *) {
      textView = UITextView(usingTextLayoutManager: false)
      textView.frame = bounds
    } else {
      textView = UITextView(frame: bounds)
    }
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

  private func calculateLayouts(_ availableRect: CGRect)
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

    textView.frame = CGRect(origin: textView.frame.origin,
                            size: CGSize(width: availableRect.width,
                                         height: textView.frame.height))

    textView.textContainer.exclusionPaths = exclusionPaths
    textView.layoutManager.ensureLayout(for: textView.textContainer)

    let textHeight = textView.sizeThatFits(availableRect.size).height

    return (rightButtonFrame: rightButtonFrame, exclusionPaths: exclusionPaths,
            textHeight: textHeight)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let availableRect = CGRect(origin: .zero, size: size).inset(by: kEdgeInsets)
    let layout = calculateLayouts(availableRect)

    return CGSize(width: availableRect.width, height: max(kMinimumHeight,
                                                          layout.textHeight + kEdgeInsets
                                                            .top + kEdgeInsets.bottom))
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    var availableRect = bounds.inset(by: kEdgeInsets)
    let layout = calculateLayouts(availableRect)

    if let rightButton = rightButton, let rightButtonFrame = layout.rightButtonFrame {
      rightButton.frame = rightButtonFrame
    }

    let textViewSize = CGSize(width: availableRect.width, height: layout.textHeight)

    // Center the text vertically.
    if textViewSize.height < availableRect.size.height {
      availableRect.origin.y += floor((availableRect.size.height - textViewSize.height) / 2)
      availableRect.size = textViewSize
    }

    textView.frame = availableRect
  }

  override func update() {
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
    item.rightButtonImage = nil

    rightButton?.removeFromSuperview()
    rightButton = nil
    textView.textContainer.exclusionPaths = []
  }

  @objc func didTapRightButton() {
    item.rightButtonCallback?(self)
  }
}
