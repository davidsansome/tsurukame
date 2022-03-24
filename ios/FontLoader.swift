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

import CoreText
import Foundation

struct FontDefinition {
  var fontName: String
  var fileName: String
  var displayName: String
  var sizeBytes: Int64
  init(_ fontName: String, _ fileName: String, _ displayName: String, _ sizeBytes: Int64) {
    self.fontName = fontName
    self.fileName = fileName
    self.displayName = displayName
    self.sizeBytes = sizeBytes
  }
}

class Font: NSObject {
  static let fontPreviewText = "色は匂へど散りぬるを我が世誰ぞ常ならん有為の奥山今日越えて浅き夢見じ酔ひもせず"
  static let fontDefinitions: [FontDefinition] = [
    FontDefinition("ArmedBanana", "armed-banana.ttf", "Armed Banana", 3_298_116),
    FontDefinition("darts font", "darts-font.woff", "Darts", 1_349_440),
    FontDefinition("Hosofuwafont", "hoso-fuwa.ttf", "Hoso Fuwa", 5_910_760),
    FontDefinition("nagayama_kai", "nagayama-kai.otf", "Nagayama Kai calligraphy", 15_576_732),
    FontDefinition("santyoume-font", "san-chou-me.ttf", "San Chou Me", 4_428_896),
  ]
  static func loadFont(path: String) -> Bool {
    guard let data = FileManager.default.contents(atPath: path) else { return false }
    let provider = CGDataProvider(data: NSData(data: data))!
    let font = CGFont(provider)!
    return CTFontManagerRegisterGraphicsFont(font, nil)
  }

  var definition: FontDefinition
  var fontName: String { definition.fontName }
  var fileName: String { definition.fileName }
  var displayName: String { definition.displayName }
  var sizeBytes: Int64 { definition.sizeBytes }
  var available: Bool = false

  init(definition: FontDefinition) {
    self.definition = definition
    super.init()
    reload()
  }

  func canRender(_ text: String) -> Bool {
    let fontRef = CTFontCreateWithName(NSString(string: fontName), 0.0, nil)
    let count = text.count, characters = text.utf16.map { $0 }
    let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: count)
    let canRender = CTFontGetGlyphsForCharacters(fontRef, characters, glyphs, count)
    if canRender {
      // Check every glyph has a path.
      for i in 0 ..< count {
        guard CTFontCreatePathForGlyph(fontRef, glyphs[i], nil) != nil else { return false }
      }
    }
    return canRender
  }

  func reload() {
    if available { return }
    if UIFont.fontNames(forFamilyName: fontName).count > 0 {
      available = true
      return
    }

    // Try to load a built-in font first.
    if let path = Bundle.main.path(forResource: "fonts/\(fileName)", ofType: nil) {
      if Font.loadFont(path: path) {
        available = true
        return
      }
    }

    // Try to load the downloaded font.
    let path = "\(FontLoader.cacheDirectoryPath)/\(fileName)"
    NSLog("Loading font \(path)")
    if Font.loadFont(path: path) {
      available = true
      return
    }
  }

  func didDelete() { available = false }
  func loadScreenshot() -> UIImage! { UIImage(named: fontName) }
}

class FontLoader: NSObject {
  static var cacheDirectoryPath: String {
    "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/fonts"
  }

  let allFonts: [Font]

  override init() {
    var allFonts: [Font] = []
    for definition in Font.fontDefinitions {
      allFonts.append(Font(definition: definition))
    }
    self.allFonts = allFonts
    super.init()
  }

  func font(fileName: String) -> Font? {
    for font in allFonts {
      if font.fileName == fileName { return font }
    }
    return nil
  }
}
