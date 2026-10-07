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

class MainTitleView: UIView {
  @IBOutlet var stackView: UIStackView!
  @IBOutlet var usernameLabel: UILabel!
  @IBOutlet var levelLabel: UILabel!
  @IBOutlet var imageContainer: UIView!
  @IBOutlet var imageView: UIImageView!

  @IBOutlet var bottomConstraint: NSLayoutConstraint!

  required init?(coder: NSCoder) {
    super.init(coder: coder)

    let nib = UINib(nibName: "MainTitleView", bundle: Bundle(for: type(of: self)))
    let container = nib.instantiate(withOwner: self, options: nil).first as! UIView

    addSubview(container)
    addConstraints([
      container.leftAnchor.constraint(equalTo: leftAnchor),
      container.rightAnchor.constraint(equalTo: rightAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor),
      container.topAnchor.constraint(equalTo: topAnchor),
    ])
  }

  override func didMoveToSuperview() {
    // Ink on paper: no text shadows, and a hairline ring around the avatar instead of a drop
    // shadow.
    usernameLabel.textColor = TKMStyle.Color.label
    usernameLabel.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
    levelLabel.textColor = TKMStyle.Color.grey33
    levelLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
    imageContainer.layer.borderWidth = 2
    imageContainer.layer.borderColor = TKMStyle.Color.cellBackground.cgColor

    imageView.layer.masksToBounds = true

    // Set rounded corners on the user image.
    let cornerRadius = imageView.bounds.size.width / 2
    imageContainer.layer.cornerRadius = cornerRadius
    imageView.layer.cornerRadius = cornerRadius

    backgroundColor = .clear

    // Make the layout fit better on iPad.
    if UIDevice.current.userInterfaceIdiom == .pad {
      stackView.axis = .horizontal
      stackView.spacing = 12
      stackView.distribution = .fill
      bottomConstraint.constant = 6
      setNeedsLayout()
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    imageContainer.layer.borderColor = TKMStyle.Color.cellBackground
      .resolvedColor(with: traitCollection).cgColor
  }

  func update(username: String,
              level: Int,
              guruKanji: Int,
              imageURL: URL?) {
    if let imageURL = imageURL {
      NSLog("Loading Gravatar at URL: \(imageURL)")
      imageView.hnk_setImage(from: imageURL)
    }

    usernameLabel.text = username
    levelLabel.text = "Level \(level) \u{00B7} \(guruKanji) kanji learned"
  }
}
