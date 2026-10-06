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

// Seigaiha (青海波) — overlapping rows of concentric arcs, the sea the turtle swims in. The top of
// the pattern fades into whatever is behind the view.
class WavesView: UIView {
  var waveColor = UIColor(red: 0.165, green: 0.227, blue: 0.357, alpha: 1.0) {
    didSet { setNeedsDisplay() }
  }

  var fillColor = TKMStyle.Color.night {
    didSet { setNeedsDisplay() }
  }

  // Radius of each scale of the pattern, in points.
  var radius: CGFloat = 14 {
    didSet { setNeedsDisplay() }
  }

  private let fadeMask = CAGradientLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    isOpaque = false
    backgroundColor = .clear
    isUserInteractionEnabled = false
    contentMode = .redraw

    fadeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
    fadeMask.locations = [0, 0.55]
    layer.mask = fadeMask
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    fadeMask.frame = bounds
  }

  override func draw(_: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let fill = fillColor.resolvedColor(with: traitCollection)
    let line = waveColor.resolvedColor(with: traitCollection)

    // Draw rows from the top down, so each row of scales overlaps the one behind it.
    let rowStep = radius / 2
    let rows = Int(ceil(bounds.height / rowStep)) + 2
    let columns = Int(ceil(bounds.width / (radius * 2))) + 2
    for row in 0 ..< rows {
      let y = CGFloat(row) * rowStep
      let xOffset = row % 2 == 0 ? 0 : radius
      for column in -1 ..< columns {
        let x = CGFloat(column) * radius * 2 + xOffset
        // Alternate filled discs of decreasing size to make the concentric rings.
        for ring in 0 ..< 4 {
          let r = radius * (1 - CGFloat(ring) * 0.22)
          context.setFillColor((ring % 2 == 0 ? line : fill).cgColor)
          context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
      }
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    setNeedsDisplay()
  }
}
