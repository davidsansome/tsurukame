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

// The header of the review summary: a paper crane over the sun, "Session complete", and the
// session's accuracy and count.
class SessionCompleteItem: TableModelItem {
  let correct: Int
  let total: Int

  init(correct: Int, total: Int) {
    self.correct = correct
    self.total = total
  }

  var accuracyText: String {
    total == 0 ? "–" : "\(Int(Double(correct) / Double(total) * 100.0))%"
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: SessionCompleteCell.self)
  }
}

class SessionCompleteCell: TableModelCell {
  @TypedModelItem var item: SessionCompleteItem

  private let accuracyCard = SessionStatCard()
  private let correctCard = SessionStatCard()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    let illustration = UIImageView(image: Asset.sessionComplete.image)
    illustration.contentMode = .scaleAspectFit
    illustration.isAccessibilityElement = false

    let title = UILabel()
    title.text = "Session complete"
    title.font = UIFont.systemFont(ofSize: 30, weight: .heavy)
    title.textColor = TKMStyle.Color.label
    title.textAlignment = .center
    title.accessibilityTraits = .header

    let cards = UIStackView(arrangedSubviews: [accuracyCard, correctCard])
    cards.distribution = .fillEqually
    cards.spacing = 10

    let stack = UIStackView(arrangedSubviews: [illustration, title, cards])
    stack.axis = .vertical
    stack.alignment = .fill
    stack.spacing = 14
    stack.setCustomSpacing(22, after: title)
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      illustration.heightAnchor.constraint(equalToConstant: 180),
      cards.heightAnchor.constraint(equalToConstant: 84),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    backgroundConfiguration = UIBackgroundConfiguration.clear()
    accuracyCard.set(value: item.accuracyText, caption: "Accuracy")
    correctCard.set(value: "\(item.correct)/\(item.total)", caption: "Correct")
  }
}

private class SessionStatCard: UIView {
  private let valueLabel = UILabel()
  private let captionLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = 18
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    isAccessibilityElement = true

    valueLabel.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
    valueLabel.textColor = TKMStyle.Color.label
    captionLabel.font = UIFont.systemFont(ofSize: 12)
    captionLabel.textColor = TKMStyle.Color.grey33

    let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
    stack.axis = .vertical
    stack.spacing = 2
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    updateBorder()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func set(value: String, caption: String) {
    valueLabel.text = value
    captionLabel.text = caption
    accessibilityLabel = "\(caption): \(value)"
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateBorder()
  }

  private func updateBorder() {
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }
}
