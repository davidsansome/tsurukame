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
  var radius: CGFloat = 28 {
    didSet { setNeedsDisplay() }
  }

  private let fadeMask = CAGradientLayer()

  // Outer edge of each disc, as a fraction of the radius: line, gap, line, gap, line, gap, dot.
  private static let ringScales: [CGFloat] = [1, 0.89, 0.71, 0.61, 0.425, 0.325, 0.14]

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
    // Every disc replaces what's under it rather than blending, so each row of scales hides the
    // one behind it even when the colours are translucent (a clear fill punches holes).
    context.setBlendMode(.copy)

    // Draw rows from the top down, so each row of scales overlaps the one behind it.
    let rowStep = radius / 2
    let rows = Int(ceil(bounds.height / rowStep)) + 2
    let columns = Int(ceil(bounds.width / (radius * 2))) + 2
    for row in 0 ..< rows {
      let y = CGFloat(row) * rowStep
      let xOffset = row % 2 == 0 ? 0 : radius
      for column in -1 ..< columns {
        let x = CGFloat(column) * radius * 2 + xOffset
        // Alternate filled discs of decreasing size to make thin concentric rings and a dot in the
        // middle, in the proportions of the mocks' pattern.
        for (ring, scale) in WavesView.ringScales.enumerated() {
          let r = radius * scale
          let isLine = ring % 2 == 0
          context.setFillColor((isLine ? line : fill).cgColor)
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
