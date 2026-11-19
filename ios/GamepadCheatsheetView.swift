// Copyright 2026 David Sansome
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

import UIKit

final class GamepadCheatsheetView: UIView {
  struct Item: Equatable {
    let icon: Icon
    let title: String
  }

  enum Icon: Equatable {
    case faceButton(String, UInt32)
    case rightBumper

    var text: String {
      switch self {
      case let .faceButton(text, _): return text
      case .rightBumper: return "RB"
      }
    }
  }

  private let stackView = UIStackView()
  private var items: [Item] = []
  private var itemViews: [UIView] = []

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  func setItems(_ items: [Item]) {
    if self.items == items { return }

    itemViews.forEach { $0.removeFromSuperview() }
    self.items = items
    itemViews = items.map(makeItemView)
    itemViews.forEach(stackView.addArrangedSubview)
  }

  func setVerticalLayout(_ vertical: Bool) {
    stackView.axis = vertical ? .vertical : .horizontal
    stackView.alignment = vertical ? .leading : .center
  }

  private func setup() {
    layer.cornerRadius = 8
    layer.masksToBounds = true
    backgroundColor = UIColor.black.withAlphaComponent(0.62)

    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.distribution = .fill
    stackView.spacing = 10
    stackView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
    ])
  }

  private func makeItemView(_ item: Item) -> UIView {
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 4

    row.addArrangedSubview(makeIconView(item.icon))

    let label = UILabel()
    label.text = item.title
    label.font = UIFontMetrics(forTextStyle: .caption1)
      .scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
    label.adjustsFontForContentSizeCategory = true
    label.textColor = .white
    label.numberOfLines = 1
    label.setContentCompressionResistancePriority(.required, for: .vertical)
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    row.addArrangedSubview(label)

    return row
  }

  private func makeIconView(_ icon: Icon) -> UIView {
    let wrapper = UIView()
    wrapper.translatesAutoresizingMaskIntoConstraints = false

    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = icon.text
    label.textAlignment = .center
    label.font = .systemFont(ofSize: 12, weight: .bold)
    label.adjustsFontForContentSizeCategory = false
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .vertical)
    wrapper.addSubview(label)

    switch icon {
    case let .faceButton(_, color):
      label.backgroundColor = colorFromHex(color)
      label.textColor = colorFromHex(0x1C212A)
      label.layer.cornerRadius = 9
      label.layer.masksToBounds = true
      NSLayoutConstraint.activate([
        wrapper.widthAnchor.constraint(equalToConstant: 24),
        wrapper.heightAnchor.constraint(equalToConstant: 24),
        label.widthAnchor.constraint(equalToConstant: 18),
        label.heightAnchor.constraint(equalToConstant: 18),
        label.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
      ])
    case .rightBumper:
      label.backgroundColor = colorFromHex(0xD6E1F6)
      label.textColor = colorFromHex(0x1C212A)
      label.layer.cornerRadius = 2
      label.layer.masksToBounds = true
      NSLayoutConstraint.activate([
        wrapper.widthAnchor.constraint(equalToConstant: 30),
        wrapper.heightAnchor.constraint(equalToConstant: 24),
        label.widthAnchor.constraint(equalToConstant: 29),
        label.heightAnchor.constraint(equalToConstant: 17),
        label.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
      ])
    }

    return wrapper
  }

  private func colorFromHex(_ hex: UInt32) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
  }
}
