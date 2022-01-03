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
import WaniKaniAPI

class SuccessAnimation {
  private static func randFloat(min: CGFloat, max: CGFloat) -> CGFloat {
    CGFloat(arc4random()) / CGFloat(UInt32.max) * (max - min) + min
  }

  private static func createSpark(superview: UIView, origin: CGPoint, size: CGFloat,
                                  distance: CGFloat,
                                  radians: CGFloat, color: UIColor, duration: TimeInterval) {
    let frame = CGRect(x: origin.x - size / 2, y: origin.y - size / 2, width: size, height: size)
    let view = UIView(frame: frame)
    view.backgroundColor = color
    view.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
    view.layer.cornerRadius = size / 2
    view.alpha = 0.0
    superview.addSubview(view)
    superview.layoutIfNeeded()

    // Fade in.
    UIView.animate(withDuration: duration * 0.2,
                   delay: 0,
                   options: .curveLinear, animations: {
                     view.alpha = 1.0
                   })

    // Explode.
    UIView.animate(withDuration: duration * 0.4,
                   delay: 0,
                   options: .curveEaseOut,
                   animations: {
                     view.center = CGPoint(x: view.center.x - distance * sin(radians),
                                           y: view.center.y - distance * cos(radians))
                     superview.layoutIfNeeded()
                   })

    // Get smaller.
    UIView.animate(withDuration: duration * 0.8,
                   delay: duration * 0.2,
                   options: .curveLinear,
                   animations: {
                     view.transform = view.transform.scaledBy(x: 0.001, y: 0.001)
                     superview.layoutIfNeeded()
                   },
                   completion: { (_: Bool) in
                     view.removeFromSuperview()
                   })

    // Fade out.
    UIView.animate(withDuration: duration * 0.2,
                   delay: duration * 0.8,
                   options: .curveEaseOut,
                   animations: {
                     view.alpha = 0.0
                   })
  }

  private static func createPlusOneText(toView: UIView, text: String, font: UIFont,
                                        color: UIColor,
                                        duration: CGFloat) {
    guard let superview = toView.superview else {
      return
    }

    let view = UILabel(frame: .zero)
    view.text = text
    view.font = font
    view.textColor = color
    view.alpha = 0.0
    view.center = CGPoint(x: toView.center.x, y: toView.center.y + font.pointSize * 1.5)
    view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
    superview.addSubview(view)
    view.sizeToFit()
    superview.layoutIfNeeded()

    // Fade in.
    UIView.animate(withDuration: duration * 0.1,
                   delay: 0,
                   options: .curveLinear,
                   animations: {
                     view.alpha = 1.0
                   })

    // Get bigger.
    UIView.animate(withDuration: duration * 0.2,
                   delay: 0,
                   usingSpringWithDamping: 0.5,
                   initialSpringVelocity: 1,
                   options: [],
                   animations: {
                     view.transform = .identity
                   })

    // Move to destination and get smaller
    UIView.animate(withDuration: duration * 0.3,
                   delay: duration * 0.7,
                   options: .curveLinear,
                   animations: {
                     view.center = toView.center
                     view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                     view.alpha = 0.1
                   },
                   completion: { (_: Bool) in
                     view.removeFromSuperview()
                   })
  }

  private static func createSpringyBillboard(originView: UIView,
                                             text: String,
                                             font: UIFont,
                                             textColor: UIColor,
                                             backgroundColor: UIColor,
                                             cornerRadius: CGFloat,
                                             padding: CGFloat,
                                             distance: CGFloat,
                                             duration: CGFloat) {
    guard let superview = originView.superview else {
      return
    }
    let angleRadians = randFloat(min: -CGFloat.pi * 0.1, max: CGFloat.pi * 0.1)

    var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, alpha: CGFloat = 0.0
    backgroundColor.getHue(&hue, saturation: &saturation, brightness: nil, alpha: &alpha)
    let borderColor = UIColor(hue: hue, saturation: saturation / 2, brightness: 1.0, alpha: alpha)

    let label = UILabel(frame: .zero)
    label.text = text
    label.font = font
    label.textColor = textColor
    label.backgroundColor = backgroundColor
    label.layer.cornerRadius = cornerRadius
    label.layer.borderColor = borderColor.cgColor
    label.layer.borderWidth = 1.5
    label.clipsToBounds = true
    label.textAlignment = .center
    label.sizeToFit()
    label.frame = label.frame.insetBy(dx: -padding, dy: -padding)

    let container = UIView(frame: label.frame)
    container.alpha = 0.0
    container.center = originView.center
    container.transform = CGAffineTransform(rotationAngle: angleRadians)
    container.layer.shadowColor = UIColor.black.cgColor
    container.layer.shadowOffset = .zero
    container.layer.shadowOpacity = 0.5
    container.layer.shadowRadius = 4
    container.clipsToBounds = false
    container.addSubview(label)

    superview.addSubview(container)
    superview.layoutIfNeeded()

    // Fade in.
    UIView.animate(withDuration: duration * 0.15,
                   delay: 0,
                   options: .curveLinear,
                   animations: {
                     container.alpha = 1.0
                   })

    // Spring to target position.
    UIView.animate(withDuration: duration * 0.3,
                   delay: 0.0,
                   usingSpringWithDamping: 0.5,
                   initialSpringVelocity: 1,
                   options: [],
                   animations: {
                     container.center =
                       CGPoint(x: container.center.x + distance * sin(angleRadians),
                               y: container.center.y - distance * cos(angleRadians))
                     superview.layoutIfNeeded()
                   })

    // Get smaller and fade out.
    UIView.animate(withDuration: duration * 0.1,
                   delay: duration * 0.85,
                   options: .curveEaseInOut,
                   animations: {
                     container.transform = container.transform.scaledBy(x: 0.001, y: 0.001)
                     container.alpha = 0.0
                     superview.layoutIfNeeded()
                   },
                   completion: { (_: Bool) in
                     label.removeFromSuperview()
                   })
  }

  private static func createExplosion(view: UIView) {
    guard let superview = view.superview else {
      return
    }

    for _ in 0 ..< 80 {
      let size = randFloat(min: 9.0, max: 11.0)
      let distance = randFloat(min: 60.0, max: 150.0)
      let duration = randFloat(min: 0.5, max: 0.7)
      let offset = randFloat(min: -1.0, max: 1.0)
      let angle = -(.pi * 0.3) * offset
      let originCenterOffset = 0.25 * offset
      let color = (arc4random_uniform(2) != 0) ? TKMStyle.explosionColor1 : TKMStyle.explosionColor2
      let origin = CGPoint(x: view.center.x + originCenterOffset * view.bounds.size.width,
                           y: view.center.y)

      createSpark(superview: superview, origin: origin, size: size, distance: distance,
                  radians: angle, color: color, duration: duration)
    }
  }

  /**
   * Specialized version of CreateExplosion that attempts to line up the sparks
   * with the characters in the SRS level dots label. The arc is also skewed
   * left so the sparks stay on screen.
   */
  private static func createDotExplosion(label: UILabel) {
    guard let superview = label.superview, let text = label.attributedText else {
      return
    }

    let dotCount = text.length
    let letterWidth = label.bounds.size.width / CGFloat(dotCount)

    for i in 0 ..< dotCount {
      let size = randFloat(min: 9.0, max: 11.0)
      let distance = randFloat(min: 30.0, max: 80.0)
      let duration = randFloat(min: 0.5, max: 0.7)
      let offset = randFloat(min: -1.0, max: 1.0)
      let angle = -(.pi * 0.3) * offset
      let origin = CGPoint(x: label.frame.origin.x + (CGFloat(i) * letterWidth), y: label.center.y)

      if let color = text.attribute(.foregroundColor, at: i, effectiveRange: nil) as? UIColor {
        createSpark(superview: superview, origin: origin, size: size, distance: distance,
                    radians: angle, color: color, duration: duration)
      }
    }
  }

  static func run(answerField: UIView,
                  doneLabel: UIView,
                  srsLevelLabel: UILabel,
                  isSubjectFinished: Bool,
                  didLevelUp: Bool,
                  newSrsStage: SRSStage) {
    if Settings.animateParticleExplosion {
      createExplosion(view: answerField)
    }

    if isSubjectFinished {
      if Settings.animatePlusOne {
        createPlusOneText(toView: doneLabel,
                          text: "+1",
                          font: UIFont.boldSystemFont(ofSize: 20.0),
                          color: .white,
                          duration: 1.5)
      }

      if Settings.showSRSLevelIndicator {
        createDotExplosion(label: srsLevelLabel)
      }

      if didLevelUp, Settings.animateLevelUpPopup {
        switch newSrsStage {
        // Only show the level up popup for the first SRS stage in each category.
        case .guru1, .master, .enlightened, .burned:
          let srsLevelColor = TKMStyle.color(forSRSStageCategory: newSrsStage.category)
          let srsLevelString = newSrsStage.category.description

          createSpringyBillboard(originView: answerField, text: srsLevelString,
                                 font: UIFont.systemFont(ofSize: 16.0),
                                 textColor: .white, backgroundColor: srsLevelColor,
                                 cornerRadius: 5.0,
                                 padding: 6.0,
                                 distance: 100.0,
                                 duration: 3.0)
        default:
          break
        }
      }
    }
  }
}
