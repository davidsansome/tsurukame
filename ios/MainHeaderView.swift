// Copyright 2019 David Sansome
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

private let kUserGradientYOffset: CGFloat = 450
private let kUserGradientStartPoint: CGFloat = 0.8

@objc protocol MainHeaderViewDelegate {
  func searchButtonTapped()
  func settingsButtonTapped()
}

@IBDesignable
class MainHeaderView: UIView {
  var contentView: UIView!
  @IBOutlet var userContainer: UIView!
  @IBOutlet var usernameLabel: UILabel!
  @IBOutlet var levelLabel: UILabel!
  @IBOutlet var settingsButton: UIButton!
  @IBOutlet var searchButton: UIButton!
  @IBOutlet var imageContainer: UIView!
  @IBOutlet var imageView: UIImageView!

  @IBOutlet var vacationContainer: UIView!
  @IBOutlet var vacationLabel: UILabel!
  @IBOutlet var vacationDetail: UILabel!

  @IBOutlet var vacationZeroHeightConstraint: NSLayoutConstraint!
  @IBOutlet var showVacationConstraint: NSLayoutConstraint!
  @IBOutlet var hideVacationConstraint: NSLayoutConstraint!

  @objc weak var delegate: MainHeaderViewDelegate?

  weak var userGradientLayer: CAGradientLayer!
  weak var vacationGradientLayer: CAGradientLayer!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    contentView = loadViewFromNib()
    contentView.frame = bounds
    contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    contentView.setContentHuggingPriority(.defaultHigh, for: .vertical)
    addSubview(contentView)

    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    setContentHuggingPriority(.defaultHigh, for: .vertical)
    backgroundColor = nil
  }

  func loadViewFromNib() -> UIView {
    let nib = UINib(nibName: "MainHeaderView", bundle: Bundle(for: type(of: self)))
    return nib.instantiate(withOwner: self, options: nil).first as! UIView
  }

  override func didMoveToSuperview() {
    // Set a gradient background for the user container.
    let userGradientLayer = CAGradientLayer()
    userGradientLayer.colors = TKMStyle.radicalGradient
    userGradientLayer.startPoint = CGPoint(x: 0.5, y: kUserGradientStartPoint)
    userContainer.layer.insertSublayer(userGradientLayer, at: 0)
    userContainer.layer.masksToBounds = false
    self.userGradientLayer = userGradientLayer

    // Set a gradient background for the vacation container.
    let vacationGradientLayer = CAGradientLayer()
    vacationGradientLayer.colors = TKMStyle.kanjiGradient
    vacationGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
    vacationContainer.layer.insertSublayer(vacationGradientLayer, at: 0)
    vacationContainer.layer.masksToBounds = false
    self.vacationGradientLayer = vacationGradientLayer

    // Add shadows to things in the user info view.
    TKMStyle.addShadowToView(imageView, offset: 2.0, opacity: 0.4, radius: 4.0)
    TKMStyle.addShadowToView(usernameLabel, offset: 1.0, opacity: 0.4, radius: 4.0)
    TKMStyle.addShadowToView(levelLabel, offset: 1.0, opacity: 0.2, radius: 2.0)

    imageView.layer.masksToBounds = true

    // Add shadows to things in the vacation view.
    TKMStyle.addShadowToView(vacationLabel, offset: 1.0, opacity: 0.4, radius: 2.0)
  }

  override func layoutSubviews() {
    vacationDetail.preferredMaxLayoutWidth = vacationDetail.bounds.width
    layoutIfNeeded()
    super.layoutSubviews()

    var userGradientFrame = userContainer.bounds
    userGradientFrame.origin.y -= kUserGradientYOffset
    userGradientFrame.size.height += kUserGradientYOffset
    userGradientLayer.frame = userGradientFrame

    vacationGradientLayer.frame = vacationContainer.bounds

    // Set rounded corners on the user image.
    let cornerRadius = imageView.bounds.size.height / 2
    imageContainer.layer.cornerRadius = cornerRadius
    imageView.layer.cornerRadius = cornerRadius
  }

  private func setVacationContainer(visible: Bool) {
    hideVacationConstraint.isActive = !visible
    showVacationConstraint.isActive = visible
    vacationZeroHeightConstraint.isActive = !visible
    setNeedsLayout()
  }

  @objc func update(username: String, level: Int, guruKanji: Int, imageURL: URL?, vacationMode: Bool) {
    if let imageURL = imageURL {
      imageView.hnk_setImage(from: imageURL)
    }

    usernameLabel.text = username
    levelLabel.text = "Level \(level) \u{00B7} learned \(guruKanji) kanji"
    setVacationContainer(visible: vacationMode)
  }

  @IBAction func didTapSearchButton(_: Any) {
    delegate?.searchButtonTapped()
  }

  @IBAction func didTapSettingsButton(_: Any) {
    delegate?.settingsButtonTapped()
  }
}
