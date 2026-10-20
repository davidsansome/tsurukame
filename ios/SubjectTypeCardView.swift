// Copyright David Sansome
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
import WaniKaniAPI

protocol SubjectTypeCardDelegate: AnyObject {
  func didTapSubjectTypeCard(_ card: SubjectTypeCardView)
}

class SubjectTypeCardView: UIView {
  let subjectType: TKMSubject.TypeEnum
  let count: Int
  weak var delegate: SubjectTypeCardDelegate?

  private let containerView = UIView()
  private let emojiLabel = UILabel()
  private let titleLabel = UILabel()
  private let countLabel = UILabel()
  private let checkmarkImageView = UIImageView()
  private let gradientLayer = CAGradientLayer()

  var isSelected: Bool = false {
    didSet {
      updateAppearance()
    }
  }

  init(subjectType: TKMSubject.TypeEnum, count: Int, delegate: SubjectTypeCardDelegate? = nil) {
    self.subjectType = subjectType
    self.count = count
    self.delegate = delegate
    super.init(frame: .zero)
    setupViews()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    // Container with gradient background
    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.layer.cornerRadius = 16
    containerView.layer.masksToBounds = true
    addSubview(containerView)

    // Add gradient layer
    gradientLayer.cornerRadius = 16
    containerView.layer.insertSublayer(gradientLayer, at: 0)

    // Stack view for content
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = 4
    containerView.addSubview(stackView)

    // Emoji
    emojiLabel.font = UIFont(name: TKMStyle.japaneseFontName, size: 40)
    emojiLabel.textColor = .white
    emojiLabel.textAlignment = .center
    stackView.addArrangedSubview(emojiLabel)

    // Title
    titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    titleLabel.textColor = .white
    titleLabel.textAlignment = .center
    stackView.addArrangedSubview(titleLabel)

    // Count
    countLabel.font = .systemFont(ofSize: 24, weight: .bold)
    countLabel.textColor = .white
    countLabel.textAlignment = .center
    stackView.addArrangedSubview(countLabel)

    // Checkmark
    checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
    checkmarkImageView.tintColor = .white
    checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(checkmarkImageView)

    // Set content based on type
    switch subjectType {
    case .radical:
      emojiLabel.text = "幺"
      titleLabel.text = "Radical"
    case .kanji:
      emojiLabel.text = "字"
      titleLabel.text = "Kanji"
    case .vocabulary:
      emojiLabel.text = "語"
      titleLabel.text = "Vocab"
    default:
      break
    }

    countLabel.text = "\(count)"

    // Constraints
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      containerView.heightAnchor.constraint(equalToConstant: 120),

      stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      stackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor,
                                         constant: 12),
      stackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor,
                                          constant: -12),

      checkmarkImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
      checkmarkImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,
                                                   constant: -8),
      checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
      checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
    ])

    // Tap gesture
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGesture)

    updateAppearance()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = containerView.bounds
  }

  private func updateAppearance() {
    let gradient: [CGColor]
    switch subjectType {
    case .radical:
      gradient = TKMStyle.radicalGradient
    case .kanji:
      gradient = TKMStyle.kanjiGradient
    case .vocabulary:
      gradient = TKMStyle.vocabularyGradient
    default:
      gradient = []
    }

    gradientLayer.colors = gradient
    checkmarkImageView.isHidden = !isSelected
    containerView.alpha = isSelected ? 1.0 : 0.5

    // Add shadow for selected state
    if isSelected {
      containerView.layer.shadowColor = UIColor.black.cgColor
      containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
      containerView.layer.shadowOpacity = 0.2
      containerView.layer.shadowRadius = 8
      containerView.layer.masksToBounds = false
      containerView.clipsToBounds = false
    } else {
      containerView.layer.shadowOpacity = 0
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateAppearance()
  }

  @objc private func handleTap() {
    delegate?.didTapSubjectTypeCard(self)
  }
}
