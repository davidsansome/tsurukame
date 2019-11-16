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

func UIColorFromHex(_ hexColor: Int32) -> UIColor {
  let red = (CGFloat)((hexColor & 0xFF0000) >> 16) / 255
  let green = (CGFloat)((hexColor & 0x00FF00) >> 8) / 255
  let blue = (CGFloat)(hexColor & 0x0000FF) / 255
  return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
}

@objc
@objcMembers
class TKMStyle: NSObject {
  class func addShadowToView(_ view: UIView, offset: Float, opacity: Float, radius: Float) {
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOffset = CGSize(width: 0.0, height: Double(offset))
    view.layer.shadowOpacity = opacity
    view.layer.shadowRadius = CGFloat(radius)
    view.clipsToBounds = false
  }

  static let defaultTintColor = UIColor(red: 0.0, green: 122.0 / 255.0, blue: 1.0, alpha: 1.0)
  static let radicalColor1 = UIColorFromHex(0x00AAFF)
  static let radicalColor2 = UIColorFromHex(0x0093DD)
  static let kanjiColor1 = UIColorFromHex(0xFF00AA)
  static let kanjiColor2 = UIColorFromHex(0xDD0093)
  static let vocabularyColor1 = UIColorFromHex(0xAA00FF)
  static let vocabularyColor2 = UIColorFromHex(0x9300DD)
  static let lockedColor1 = UIColorFromHex(0x505050)
  static let lockedColor2 = UIColorFromHex(0x484848)
  static let greyColor = UIColorFromHex(0xC8C8C8)

  // The [Any] types force these to be exposed to objective-C as an untyped NSArray*.
  static let radicalGradient: [Any] = [radicalColor1.cgColor, radicalColor2.cgColor]
  static let kanjiGradient: [Any] = [kanjiColor1.cgColor, kanjiColor2.cgColor]
  static let vocabularyGradient: [Any] = [vocabularyColor1.cgColor, vocabularyColor2.cgColor]
  static let lockedGradient: [Any] = [lockedColor1.cgColor, lockedColor2.cgColor]

  class func color2(forSubjectType subjectType: TKMSubject_Type) -> UIColor {
    switch subjectType {
    case .radical:
      return radicalColor2
    case .kanji:
      return kanjiColor2
    case .vocabulary:
      return vocabularyColor2
    @unknown default:
      fatalError()
    }
  }

  class func gradient(forAssignment assignment: TKMAssignment) -> [Any] {
    switch assignment.subjectType {
    case .radical:
      return radicalGradient
    case .kanji:
      return kanjiGradient
    case .vocabulary:
      return vocabularyGradient
    @unknown default:
      fatalError()
    }
  }

  class func gradient(forSubject subject: TKMSubject) -> [Any] {
    if subject.hasRadical {
      return radicalGradient
    } else if subject.hasKanji {
      return kanjiGradient
    } else if subject.hasVocabulary {
      return vocabularyGradient
    }
    return []
  }

  static let japaneseFontName = "Hiragino Sans"

  // Tries to load fonts from the list of font names, in order, until one is found.
  private class func loadFont(_ names: [String], size: CGFloat) -> UIFont {
    for name in names {
      if let font = UIFont(name: name, size: size) {
        return font
      }
    }
    return UIFont.systemFont(ofSize: size)
  }

  class func japaneseFont(size: CGFloat) -> UIFont {
    return UIFont(name: japaneseFontName, size: size)!
  }

  class func japaneseFontLight(size: CGFloat) -> UIFont {
    return loadFont(["HiraginoSans-W3",
                     "HiraginoSans-W2",
                     "HiraginoSans-W1",
                     "HiraginoSans-W4",
                     "HiraginoSans-W5"], size: size)
  }

  class func japaneseFontBold(size: CGFloat) -> UIFont {
    return loadFont(["HiraginoSans-W8",
                     "HiraginoSans-W7",
                     "HiraginoSans-W6",
                     "HiraginoSans-W5"], size: size)
  }
}
