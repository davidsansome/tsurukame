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

@objc(TKMActionModelItem)
class ActionModelItem: NSObject, TKMModelItem {
  var leftButton: UIButton?
  var rightButton: UIButton?

  init(leftButton: UIButton?, rightButton: UIButton?) {
    self.leftButton = leftButton
    self.rightButton = rightButton
    super.init()
  }

  func cellClass() -> AnyClass! {
    ActionModelCell.self
  }
}

/**
 ModelItem for 1- or 2-button action line
 */
class ActionModelCell: TKMModelCell {
  var leftButton: UIButton? {
    didSet {
      updateView()
    }
  }

  var rightButton: UIButton? {
    didSet {
      updateView()
    }
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    selectionStyle = .none
    isUserInteractionEnabled = true
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    var availableRect = CGRect(origin: .zero, size: size).inset(by: kEdgeInsets)
    let buttonHeight = max(rightButton?.bounds.height ?? 0, leftButton?.bounds.height ?? 0)
    availableRect.size.height = max(kMinimumHeight,
                                    buttonHeight + kEdgeInsets.top + kEdgeInsets.bottom)
    return availableRect.size
  }

  func updateView() {
    NSLayoutConstraint.activate([
      heightAnchor.constraint(greaterThanOrEqualToConstant: kMinimumHeight),
    ])

    if let leftButton = leftButton {
      addSubview(leftButton)
      leftButton.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        leftButton.topAnchor.constraint(equalTo: topAnchor),
        leftButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        leftButton.leftAnchor.constraint(equalTo: leftAnchor),
        leftButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
      ])
    }

    if let rightButton = rightButton {
      addSubview(rightButton)
      rightButton.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        rightButton.topAnchor.constraint(equalTo: topAnchor),
        rightButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        rightButton.rightAnchor.constraint(equalTo: rightAnchor),
        rightButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
      ])
    }
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update(with baseItem: TKMModelItem!) {
    super.update(with: baseItem)

    if let item = baseItem as? ActionModelItem {
      leftButton = item.leftButton
      rightButton = item.rightButton
    }
    setNeedsLayout()
  }
}
