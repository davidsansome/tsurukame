// Copyright 2021 David Sansome
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
private let kUserMargin: CGFloat = 8.0
private let kVacationMargin: CGFloat = 8.0
private let kProgressBarHeight: CGFloat = 3.0

@objc protocol MainHeaderViewDelegate {
  func searchButtonTapped()
  func settingsButtonTapped()
}

@IBDesignable
class MainHeaderView: UIView {
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

  @IBOutlet var progressView: UIProgressView!

  @objc weak var delegate: MainHeaderViewDelegate?

  weak var userGradientLayer: CAGradientLayer!
  weak var vacationGradientLayer: CAGradientLayer!

  private var isOnVacation = false
  private var isShowingProgress = false

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    let nib = UINib(nibName: "MainHeaderView", bundle: Bundle(for: type(of: self)))
    nib.instantiate(withOwner: self, options: nil)

    addSubview(userContainer)
    addSubview(vacationContainer)
    addSubview(progressView)
  }

  override func didMoveToSuperview() {
    backgroundColor = UIColor.clear

    // Set a gradient background for the user container.
    let userGradientLayer = CAGradientLayer()
    userGradientLayer.startPoint = CGPoint(x: 0.5, y: kUserGradientStartPoint)
    userContainer.layer.insertSublayer(userGradientLayer, at: 0)
    userContainer.layer.masksToBounds = false
    self.userGradientLayer = userGradientLayer

    // Set a gradient background for the vacation container.
    let vacationGradientLayer = CAGradientLayer()
    vacationGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
    vacationContainer.layer.insertSublayer(vacationGradientLayer, at: 0)
    vacationContainer.layer.masksToBounds = false
    self.vacationGradientLayer = vacationGradientLayer

    updateGradientColors()

    // Add shadows to things in the user info view.
    TKMStyle.addShadowToView(imageContainer, offset: 2.0, opacity: 0.4, radius: 4.0)
    TKMStyle.addShadowToView(usernameLabel, offset: 1.0, opacity: 0.4, radius: 4.0)
    TKMStyle.addShadowToView(levelLabel, offset: 1.0, opacity: 0.2, radius: 2.0)

    imageView.layer.masksToBounds = true

    // Add shadows to things in the vacation view.
    TKMStyle.addShadowToView(vacationLabel, offset: 1.0, opacity: 0.4, radius: 2.0)

    // Set rounded corners on the user image.
    let cornerRadius = imageView.bounds.size.height / 2
    imageContainer.layer.cornerRadius = cornerRadius
    imageView.layer.cornerRadius = cornerRadius

    // Scale the progress view.
    let progressBarScale = kProgressBarHeight / progressView.sizeThatFits(CGSize.zero).height
    progressView.transform = CGAffineTransform(scaleX: 1.0, y: progressBarScale)
  }

  func updateGradientColors() {
    userGradientLayer.colors = TKMStyle.radicalGradient
    vacationGradientLayer.colors = TKMStyle.kanjiGradient
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width
    vacationDetail.preferredMaxLayoutWidth = width - kVacationMargin * 2

    var height = userContainer.sizeThatFits(CGSize(width: width, height: 0)).height + kUserMargin

    if isOnVacation {
      height += vacationContainer.sizeThatFits(CGSize(width: width, height: 0)).height
    }

    height += kProgressBarHeight

    return CGSize(width: size.width, height: height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let width = bounds.width

    // Layout the user container.
    var origin = CGPoint(x: 0, y: 0)
    var userContainerSize = userContainer.sizeThatFits(CGSize(width: width, height: 0))
    userContainerSize.width = width
    userContainer.frame = CGRect(origin: origin,
                                 size: userContainerSize)
    origin.y += userContainerSize.height + kUserMargin

    // Position the vacation container below it.
    var vacationContainerSize = CGSize(width: 0, height: 0)
    if isOnVacation {
      let vacationContainerHeight = vacationContainer.sizeThatFits(CGSize(width: width, height: 0))
        .height
      vacationContainerSize = CGSize(width: width, height: vacationContainerHeight)
    }
    vacationContainer.frame = CGRect(origin: origin, size: vacationContainerSize)

    origin.y += vacationContainerSize.height

    // Position the progress bar below that.
    progressView.center = CGPoint(x: origin.x + width / 2, y: origin.y + kProgressBarHeight / 2)
    progressView.bounds = CGRect(x: 0, y: 0, width: width, height: kProgressBarHeight)

    // Position the gradients.
    var userGradientFrame = userContainer.bounds
    userGradientFrame.origin.y -= kUserGradientYOffset
    userGradientFrame.size.height += kUserGradientYOffset + kUserMargin
    userGradientLayer.frame = userGradientFrame

    vacationGradientLayer.frame = vacationContainer.bounds
  }

  @objc func update(username: String,
                    level: Int,
                    guruKanji: Int,
                    imageURL: URL?,
                    vacationMode: Bool) {
    if let imageURL = imageURL {
      imageView.hnk_setImage(from: imageURL)
    }

    usernameLabel.text = username
    levelLabel.text = "Level \(level) \u{00B7} learned \(guruKanji) kanji"
    isOnVacation = vacationMode
    vacationContainer.alpha = isOnVacation ? 1.0 : 0.0
    setNeedsLayout()
  }

  private var progressKvoToken: NSKeyValueObservation?

  @objc func setProgress(progress: Progress) {
    progressKvoToken?.invalidate()
    progressKvoToken = progress.observe(\.isFinished, options: [.new]) { _, change in
      if let isFinished = change.newValue, isFinished {
        self.progressKvoToken?.invalidate()

        UIView.animate(withDuration: 0.6) {
          self.progressView.alpha = 0.0
        }
      }
    }

    UIView.animate(withDuration: 0.2) {
      self.progressView.alpha = 1.0
    }
    progressView.observedProgress = progress
  }

  @IBAction func didTapSearchButton(_: Any) {
    delegate?.searchButtonTapped()
  }

  @IBAction func didTapSettingsButton(_: Any) {
    delegate?.settingsButtonTapped()
  }

  override func traitCollectionDidChange(_: UITraitCollection?) {
    updateGradientColors()
  }
}
