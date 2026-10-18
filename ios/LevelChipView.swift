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

protocol LevelChipDelegate: AnyObject {
  func didTapLevelChip(_ chip: LevelChipView)
}

class LevelChipView: UIView {
  let level: Int32
  weak var delegate: LevelChipDelegate?

  private let containerView = UIView()
  private let label = UILabel()
  private let checkmarkImageView = UIImageView()

  var isSelected: Bool = false {
    didSet {
      updateAppearance()
    }
  }

  init(level: Int32, delegate: LevelChipDelegate? = nil) {
    self.level = level
    self.delegate = delegate
    super.init(frame: .zero)
    setupViews()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    containerView.translatesAutoresizingMaskIntoConstraints = false
    containerView.layer.cornerRadius = 20
    containerView.layer.borderWidth = 2
    addSubview(containerView)

    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "\(level)"
    label.font = .systemFont(ofSize: 16, weight: .semibold)
    label.textAlignment = .center
    containerView.addSubview(label)

    checkmarkImageView.image = UIImage(systemName: "checkmark")
    checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
    checkmarkImageView.contentMode = .scaleAspectFit
    containerView.addSubview(checkmarkImageView)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
      containerView.heightAnchor.constraint(equalToConstant: 40),

      label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
      label.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImageView.leadingAnchor,
                                      constant: -4),
      label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

      checkmarkImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor,
                                                   constant: -8),
      checkmarkImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
      checkmarkImageView.heightAnchor.constraint(equalToConstant: 16),
    ])

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGesture)

    updateAppearance()
  }

  private func updateAppearance() {
    if isSelected {
      containerView.backgroundColor = TKMStyle.Color.accent
      containerView.layer.borderColor = TKMStyle.Color.accent.cgColor
      label.textColor = .white
      checkmarkImageView.tintColor = .white
      label.isHidden = false
      checkmarkImageView.isHidden = false
    } else {
      containerView.backgroundColor = TKMStyle.Color.cellBackground
      containerView.layer.borderColor = TKMStyle.Color.separator.cgColor
      label.textColor = TKMStyle.Color.label
      label.isHidden = false
      checkmarkImageView.isHidden = true
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateAppearance()
  }

  @objc private func handleTap() {
    delegate?.didTapLevelChip(self)
  }
}
