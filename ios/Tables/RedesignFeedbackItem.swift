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

import Foundation

// Where users can tell us what they think of the redesign.
let kRedesignFeedbackURL =
  URL(string: "https://github.com/davidsansome/tsurukame/issues/new?title=Visual%20redesign%20feedback")!

// A one-line card at the top of the home screen asking for feedback on the redesign, with a close
// button to dismiss it.
class RedesignFeedbackItem: TableModelItem {
  let close: () -> Void

  init(close: @escaping () -> Void) {
    self.close = close
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: RedesignFeedbackCell.self)
  }
}

class RedesignFeedbackCell: TableModelCell {
  @TypedModelItem var item: RedesignFeedbackItem

  private let card = RedesignFeedbackCard()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    // Shares a section with the hero cards, but shouldn't draw a separator above them.
    separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)

    card.addAction(UIAction { _ in UIApplication.shared.open(kRedesignFeedbackURL) },
                   for: .touchUpInside)
    card.closeButton.addAction(UIAction { [weak self] _ in self?.item.close() },
                               for: .touchUpInside)

    card.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(card)
    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
      card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
      card.heightAnchor.constraint(equalToConstant: 48),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    // The card draws its own background; the row itself is transparent.
    backgroundConfiguration = UIBackgroundConfiguration.clear()
  }
}

// A paper card with an icon, a line of text and a close button. The whole card is a button.
private class RedesignFeedbackCard: UIControl {
  let closeButton = UIButton(type: .system)

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = 16
    layer.cornerCurve = .continuous
    layer.borderWidth = 1

    let icon = UIImageView(image: UIImage(systemName: "bubble.left.and.text.bubble.right"))
    icon.tintColor = TKMStyle.Color.accent
    icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15,
                                                                    weight: .semibold)
    icon.setContentHuggingPriority(.required, for: .horizontal)

    let label = UILabel()
    label.text = "Give feedback on the new app look"
    label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    label.textColor = TKMStyle.Color.label
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8

    closeButton.setImage(UIImage(systemName: "xmark",
                                 withConfiguration: UIImage
                                   .SymbolConfiguration(pointSize: 13, weight: .semibold)),
                         for: .normal)
    closeButton.tintColor = TKMStyle.Color.grey33
    closeButton.accessibilityLabel = "Dismiss"

    for view in [icon, label, closeButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
      view.isUserInteractionEnabled = view == closeButton
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      icon.centerYAnchor.constraint(equalTo: centerYAnchor),
      label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
      label.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),
      closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
    ])

    // The card is a single VoiceOver element, so offer dismissing as an action on it.
    isAccessibilityElement = true
    accessibilityTraits = .link
    accessibilityLabel = label.text
    accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Dismiss") { [weak self] _ in
        self?.closeButton.sendActions(for: .touchUpInside)
        return true
      },
    ]
    updateColors()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isHighlighted: Bool {
    didSet {
      UIView.animate(withDuration: 0.15) {
        self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
      }
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColors()
  }

  private func updateColors() {
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }
}
