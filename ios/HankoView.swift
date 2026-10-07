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

import CoreText
import Foundation

// The app's seal (判子): 鶴 over 亀, cut out of a vermilion block so whatever is behind shows
// through the characters. Each character is stretched to fill its half of the seal, the way a
// carved name seal fills its face.
class HankoView: UIView {
  // The seal is a tall rectangle: two characters stacked, each a little wider than tall.
  static let aspectRatio: CGFloat = 1.7

  // The typeface the characters are drawn in. Hiragino Mincho ships with iOS; a licensed seal
  // typeface (古印体) can be dropped in here.
  var fontName = "HiraMinProN-W6" {
    didSet { setNeedsDisplay() }
  }

  var characters = ["鶴", "亀"] {
    didSet { setNeedsDisplay() }
  }

  var sealColor = TKMStyle.Color.accent {
    didSet { setNeedsDisplay() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = .clear
    contentMode = .redraw
    isAccessibilityElement = true
    accessibilityLabel = "Tsurukame"
    accessibilityTraits = .image
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_: CGRect) {
    guard let context = UIGraphicsGetCurrentContext(), !characters.isEmpty else { return }

    let corner = bounds.width * 0.07
    let margin = bounds.width * 0.09
    sealColor.resolvedColor(with: traitCollection).setFill()
    UIBezierPath(roundedRect: bounds, cornerRadius: corner).fill()

    // Cut each character out of the block.
    context.setBlendMode(.destinationOut)
    let gap = bounds.height * 0.03
    let slotHeight = (bounds.height - margin * 2 - gap * CGFloat(characters.count - 1)) /
      CGFloat(characters.count)
    let font = CTFontCreateWithName(fontName as CFString, 100, nil)
    for (i, character) in characters.enumerated() {
      let slot = CGRect(x: margin, y: margin + CGFloat(i) * (slotHeight + gap),
                        width: bounds.width - margin * 2, height: slotHeight)
      let line = CTLineCreateWithAttributedString(NSAttributedString(string: character,
                                                                     attributes: [
                                                                       .font: font,
                                                                     ]))
      let glyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
      guard glyphBounds.width > 0, glyphBounds.height > 0 else { continue }

      context.saveGState()
      // Map the glyph's bounds onto the slot, flipping CoreText's y axis.
      context.translateBy(x: slot.minX, y: slot.maxY)
      context.scaleBy(x: slot.width / glyphBounds.width, y: -slot.height / glyphBounds.height)
      context.translateBy(x: -glyphBounds.minX, y: -glyphBounds.minY)
      context.textPosition = .zero
      CTLineDraw(line, context)
      context.restoreGState()
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    setNeedsDisplay()
  }
}
