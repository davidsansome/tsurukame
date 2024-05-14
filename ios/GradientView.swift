// Copyright 2024 David Sansome
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

class GradientView: UIView {
  override class var layerClass: AnyClass {
    CAGradientLayer.self
  }

  init(frame: CGRect, colors: [CGColor]) {
    self.colors = colors
    super.init(frame: frame)
  }

  required init?(coder: NSCoder) {
    colors = []
    super.init(coder: coder)
  }

  var colors: [CGColor] {
    didSet {
      layer.colors = colors
    }
  }

  override var layer: CAGradientLayer {
    super.layer as! CAGradientLayer
  }

  func animateColors(to newColors: [CGColor], duration: TimeInterval) {
    let oldColors = colors
    colors = newColors

    let animation = CABasicAnimation(keyPath: "colors")
    animation.duration = duration
    animation.fromValue = oldColors
    animation.toValue = newColors
    animation.fillMode = .forwards
    animation.isRemovedOnCompletion = true
    layer.add(animation, forKey: "colors")
  }
}
