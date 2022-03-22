// Copyright 2022 David Sansome
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
  @IBOutlet var container: UIView!
  @IBOutlet var usernameLabel: UILabel!
  @IBOutlet var levelLabel: UILabel!
  @IBOutlet var imageContainer: UIView!
  @IBOutlet var imageView: UIImageView!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    let nib = UINib(nibName: "MainTitleView", bundle: Bundle(for: type(of: self)))
    nib.instantiate(withOwner: self, options: nil)

    addSubview(container)
  }

  override func didMoveToSuperview() {
    // Add shadows.
    TKMStyle.addShadowToView(imageContainer, offset: 2.0, opacity: 0.4, radius: 4.0)
    TKMStyle.addShadowToView(usernameLabel, offset: 1.0, opacity: 0.4, radius: 4.0)
    TKMStyle.addShadowToView(levelLabel, offset: 1.0, opacity: 0.2, radius: 2.0)

    imageView.layer.masksToBounds = true

    // Set rounded corners on the user image.
    let cornerRadius = imageView.bounds.size.height / 2
    imageContainer.layer.cornerRadius = cornerRadius
    imageView.layer.cornerRadius = cornerRadius

    backgroundColor = .clear
  }

  func update(username: String,
              level: Int,
              guruKanji: Int,
              imageURL: URL?) {
    if let imageURL = imageURL {
      imageView.hnk_setImage(from: imageURL)
    }

    usernameLabel.text = username
    levelLabel.text = "Level \(level) \u{00B7} learned \(guruKanji) kanji"
  }
}
