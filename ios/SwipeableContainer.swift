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

import UIKit

class SwipeableContainer: UIView {
  weak var delegate: SwipeableContainerDelegate?

  private(set) var swipeConfiguration: SwipeConfiguration

  private let leftBanner: UIView
  private let rightBanner: UIView
  private let topBanner: UIView
  private let bottomBanner: UIView

  private var initialPanPoint: CGPoint = .zero
  private var currentSwipeDirection: SwipeDirection?
  private var originalGradientColors: [CGColor] = []

  // Configuration
  private let swipeThreshold: CGFloat = 200 // around 4cm depending on device
  private let angleThreshold: CGFloat = .pi / 8 // 22.5 degrees for diagonal detection
  private let kDefaultAnimationDuration: TimeInterval =
    0.25 // same as review view controller, maybe pass this around

  override init(frame: CGRect) {
    swipeConfiguration = .allDisabled
    leftBanner = UIView()
    rightBanner = UIView()
    topBanner = UIView()
    bottomBanner = UIView()

    super.init(frame: frame)

    setupBanners()
    setupGestureRecognizer()
    isUserInteractionEnabled = true
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupBanners() {
    leftBanner.backgroundColor = TKMStyle.correctAnswerColor
    rightBanner.backgroundColor = TKMStyle.incorrectAnswerColor
    topBanner.backgroundColor = TKMStyle.Color.grey33
    bottomBanner.backgroundColor = TKMStyle.Color.grey80

    leftBanner.isHidden = true
    rightBanner.isHidden = true
    topBanner.isHidden = true
    bottomBanner.isHidden = true

    updateBannerFrames()

    addSubview(leftBanner)
    addSubview(rightBanner)
    addSubview(topBanner)
    addSubview(bottomBanner)

    // Add skip icon to top banner
    let skipIcon = UIImageView(image: Asset.goforwardPlus.image)
    skipIcon.tintColor = .white
    skipIcon.translatesAutoresizingMaskIntoConstraints = false
    topBanner.addSubview(skipIcon)

    NSLayoutConstraint.activate([
      skipIcon.centerXAnchor.constraint(equalTo: topBanner.centerXAnchor),
      skipIcon.bottomAnchor.constraint(equalTo: topBanner.bottomAnchor, constant: -48),
      skipIcon.widthAnchor.constraint(equalToConstant: 24),
      skipIcon.heightAnchor.constraint(equalToConstant: 24),
    ])

    // Add "Show Answer" label to bottom banner
    let showAnswerLabel = UILabel()
    showAnswerLabel.text = "Show Answer"
    showAnswerLabel.textColor = .white
    showAnswerLabel.font = .systemFont(ofSize: 17, weight: .medium)
    showAnswerLabel.translatesAutoresizingMaskIntoConstraints = false
    bottomBanner.addSubview(showAnswerLabel)

    NSLayoutConstraint.activate([
      showAnswerLabel.centerXAnchor.constraint(equalTo: bottomBanner.centerXAnchor),
      showAnswerLabel.topAnchor.constraint(equalTo: bottomBanner.topAnchor, constant: 48),
    ])
  }

  private func updateBannerFrames() {
    leftBanner.frame = CGRect(x: -bounds.width, y: 0,
                              width: bounds.width, height: bounds.height)
    rightBanner.frame = CGRect(x: bounds.width, y: 0,
                               width: bounds.width, height: bounds.height)
    topBanner.frame = CGRect(x: 0, y: -bounds.height,
                             width: bounds.width, height: bounds.height)
    bottomBanner.frame = CGRect(x: 0, y: bounds.height,
                                width: bounds.width, height: bounds.height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateBannerFrames()
  }

  private func setupGestureRecognizer() {
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    panGesture.delegate = self
    addGestureRecognizer(panGesture)
  }

  // MARK: - Swipe Logic

  // Configuration for enabling/disabling swipe directions
  struct SwipeConfiguration {
    var isRightEnabled: Bool = false
    var isLeftEnabled: Bool = false
    var isDownEnabled: Bool = false
    var isUpEnabled: Bool = false

    static var allEnabled: SwipeConfiguration {
      SwipeConfiguration(isRightEnabled: true, isLeftEnabled: true, isDownEnabled: true,
                         isUpEnabled: true)
    }

    static var allDisabled: SwipeConfiguration {
      SwipeConfiguration()
    }
  }

  private enum SwipeDirection {
    case left, right, down, up

    static func determineDirection(from translation: CGPoint,
                                   angleThreshold: CGFloat) -> SwipeDirection? {
      // Add minimum threshold to avoid detecting tiny movements
      let minimumMovement: CGFloat = 10
      if abs(translation.x) < minimumMovement && abs(translation.y) < minimumMovement {
        return nil
      }

      // Check if movement is too diagonal
      let angle = atan2(translation.y, translation.x)
      let isInDeadZone = abs(abs(angle) - .pi / 4) < angleThreshold
      if isInDeadZone {
        return nil
      }

      let isVertical = abs(translation.y) > abs(translation.x)

      if isVertical {
        return translation.y > 0 ? .down : .up
      } else {
        return translation.x > 0 ? .right : .left
      }
    }
  }

  func updateSwipeConfiguration(_ configuration: SwipeConfiguration) {
    swipeConfiguration = configuration
  }

  private func isDirectionEnabled(_ direction: SwipeDirection) -> Bool {
    switch direction {
    case .right:
      return swipeConfiguration.isRightEnabled
    case .left:
      return swipeConfiguration.isLeftEnabled
    case .down:
      return swipeConfiguration.isDownEnabled
    case .up:
      return swipeConfiguration.isUpEnabled
    }
  }

  private func isSwipeSignificant(direction: SwipeDirection,
                                  translation: CGPoint,
                                  velocity: CGPoint) -> Bool {
    let minimumDistance: CGFloat = 20
    let velocityThreshold: CGFloat = 1000
    let velocitySlack: CGFloat = 50 // Allow some tolerance for near-zero velocities

    // Extract relevant axis value based on direction
    let (axisTranslation, axisVelocity) = switch direction {
    case .up, .down:
      (translation.y, velocity.y)
    case .left, .right:
      (translation.x, velocity.x)
    }

    // Both translation and velocity should match intended direction
    let matchesDirection = switch direction {
    case .down, .right: axisTranslation > 0 && (axisVelocity > -velocitySlack)
    case .up, .left: axisTranslation < 0 && (axisVelocity < velocitySlack)
    }

    return matchesDirection && (abs(axisTranslation) > swipeThreshold ||
      (abs(axisVelocity) > velocityThreshold &&
        abs(axisTranslation) >= minimumDistance))
  }

  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: self)

    switch gesture.state {
    case .began:
      initialPanPoint = gesture.location(in: self)
      currentSwipeDirection = SwipeDirection.determineDirection(from: translation,
                                                                angleThreshold: angleThreshold)

      // Only show the banners that are enabled by the configuration
      leftBanner.isHidden = !swipeConfiguration.isLeftEnabled
      rightBanner.isHidden = !swipeConfiguration.isRightEnabled
      topBanner.isHidden = !swipeConfiguration.isDownEnabled
      bottomBanner.isHidden = !swipeConfiguration.isUpEnabled

    case .changed:

      // keep checking until we have a direction
      if currentSwipeDirection == nil {
        currentSwipeDirection = SwipeDirection.determineDirection(from: translation,
                                                                  angleThreshold: angleThreshold)
      }

      guard let direction = currentSwipeDirection,
            isDirectionEnabled(direction) else {
        return
      }

      // Animate banners
      UIView.animate(withDuration: 0.1) {
        switch direction {
        case .down:
          let maxDistance = min(self.bounds.height, 150)
          let clampedTranslation = max(0, min(translation.y, maxDistance))
          self.topBanner.frame.origin.y = -self.bounds.height + clampedTranslation
        case .up:
          let maxDistance = min(self.bounds.height, 150)
          let clampedTranslation = max(-maxDistance, min(0, translation.y))
          self.bottomBanner.frame.origin.y = self.bounds.height + clampedTranslation
        case .right:
          self.leftBanner.frame.origin.x = -self.bounds.width + (translation.x)
        case .left:
          self.rightBanner.frame.origin.x = self.bounds.width + (translation.x)
        }
      }

    case .ended:
      let velocity = gesture.velocity(in: self)
      guard let direction = currentSwipeDirection else {
        resetBanners()
        return
      }

      if isSwipeSignificant(direction: direction, translation: translation, velocity: velocity) &&
        isDirectionEnabled(direction) {
        animateSwipeCompletion(in: direction)
      } else {
        resetBanners()
      }

    default:
      resetBanners()
    }
  }

  // MARK: - Animation

  private func animateSwipeCompletion(in direction: SwipeDirection) {
    let targetBanner: UIView!
    switch direction {
    case .right: targetBanner = leftBanner
    case .left: targetBanner = rightBanner
    case .down: targetBanner = topBanner
    case .up: targetBanner = bottomBanner
    }

    UIView.animate(withDuration: kDefaultAnimationDuration, animations: {
      // First animation: fill screen
      targetBanner.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)

    }) { _ in
      // Second animation: Fade out banner
      UIView.animate(withDuration: self.kDefaultAnimationDuration,
                     delay: 0.1,
                     options: .curveEaseOut, animations: {
                       targetBanner.alpha = 0
                     }) { _ in
        // Notify delegate
        switch direction {
        case .right: self.delegate?.containerDidSwipeRight(self)
        case .left: self.delegate?.containerDidSwipeLeft(self)
        case .down: self.delegate?.containerDidSwipeDown(self)
        case .up: self.delegate?.containerDidSwipeUp(self)
        }

        self.resetBanners()
      }
    }
  }

  private func resetBanners() {
    // Slides the banners back to their original position and hides them
    UIView.animate(withDuration: kDefaultAnimationDuration, animations: {
      self.updateBannerFrames()
    }) { _ in
      self.leftBanner.isHidden = true
      self.rightBanner.isHidden = true
      self.topBanner.isHidden = true
      self.bottomBanner.isHidden = true
      // reset alpha after hiding to reduce flicker
      self.leftBanner.alpha = 1
      self.rightBanner.alpha = 1
      self.topBanner.alpha = 1
      self.bottomBanner.alpha = 1
    }
  }
}

// MARK: - Extensions and Protocols

extension SwipeableContainer: UIGestureRecognizerDelegate {
  func gestureRecognizer(_: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer)
    -> Bool {
    // Allow tap gestures to work alongside pan
    otherGestureRecognizer is UITapGestureRecognizer
  }
}

protocol SwipeableContainerDelegate: AnyObject {
  func containerDidSwipeRight(_ container: SwipeableContainer)
  func containerDidSwipeLeft(_ container: SwipeableContainer)
  func containerDidSwipeDown(_ container: SwipeableContainer)
  func containerDidSwipeUp(_ container: SwipeableContainer)
}
