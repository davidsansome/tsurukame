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
import WaniKaniAPI

private func UIColorFromHex(_ hexColor: Int32) -> UIColor {
  let red = CGFloat((hexColor & 0xFF0000) >> 16) / 255
  let green = CGFloat((hexColor & 0x00FF00) >> 8) / 255
  let blue = CGFloat(hexColor & 0x0000FF) / 255
  return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
}

private func AdaptiveColor(light: UIColor, dark: UIColor) -> UIColor {
  if #available(iOS 13, *) {
    return UIColor { (tc: UITraitCollection) -> UIColor in
      if tc.userInterfaceStyle == .dark {
        return dark
      } else {
        return light
      }
    }
  } else {
    return light
  }
}

private func AdaptiveColorHex(light: Int32, dark: Int32) -> UIColor {
  AdaptiveColor(light: UIColorFromHex(light), dark: UIColorFromHex(dark))
}

@objc
class TKMStyle: NSObject {
  // MARK: - Shadows

  @objc class func addShadowToView(_ view: UIView, offset: Float, opacity: Float, radius: Float) {
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOffset = CGSize(width: 0.0, height: Double(offset))
    view.layer.shadowOpacity = opacity
    view.layer.shadowRadius = CGFloat(radius)
    view.clipsToBounds = false
  }

  // MARK: - WaniKani colors and gradients

  static let defaultTintColor = UIColor(red: 0.0, green: 122.0 / 255.0, blue: 1.0, alpha: 1.0)
  static let radicalColor1 = AdaptiveColorHex(light: 0x00AAFF, dark: 0x006090)
  static let radicalColor2 = AdaptiveColorHex(light: 0x0093DD, dark: 0x005080)
  static let kanjiColor1 = AdaptiveColorHex(light: 0xFF00AA, dark: 0x940060)
  static let kanjiColor2 = AdaptiveColorHex(light: 0xDD0093, dark: 0x800050)
  static let vocabularyColor1 = AdaptiveColorHex(light: 0xAA00FF, dark: 0x6100AA)
  static let vocabularyColor2 = AdaptiveColorHex(light: 0x9300DD, dark: 0x530080)
  static let lockedColor1 = UIColorFromHex(0x505050)
  static let lockedColor2 = UIColorFromHex(0x484848)
  static let readingColor1 = AdaptiveColor(light: UIColor(white: 0.235, alpha: 1),
                                           dark: UIColor(white: 0.235, alpha: 1))
  static let readingColor2 = AdaptiveColor(light: UIColor(white: 0.102, alpha: 1),
                                           dark: UIColor(white: 0.102, alpha: 1))
  static let meaningColor1 = AdaptiveColor(light: UIColor(white: 0.933, alpha: 1),
                                           dark: UIColor(white: 0.733, alpha: 1))
  static let meaningColor2 = AdaptiveColor(light: UIColor(white: 0.882, alpha: 1),
                                           dark: UIColor(white: 0.682, alpha: 1))

  static let explosionColor1 = UIColor(red: 247.0 / 255, green: 181.0 / 255, blue: 74.0 / 255,
                                       alpha: 1.0)
  static let explosionColor2 = UIColor(red: 230.0 / 255, green: 57.0 / 255, blue: 91.0 / 255,
                                       alpha: 1.0)

  static var radicalGradient: [CGColor] { [radicalColor1.cgColor, radicalColor2.cgColor] }
  static var kanjiGradient: [CGColor] { [kanjiColor1.cgColor, kanjiColor2.cgColor] }
  static var vocabularyGradient: [CGColor] { [vocabularyColor1.cgColor, vocabularyColor2.cgColor] }
  static var lockedGradient: [CGColor] { [lockedColor1.cgColor, lockedColor2.cgColor] }
  static var readingGradient: [CGColor] { [readingColor1.cgColor, readingColor2.cgColor] }
  static var meaningGradient: [CGColor] { [meaningColor1.cgColor, meaningColor2.cgColor] }

  class func color(forSRSStageCategory srsStageCategory: SRSStageCategory) -> UIColor {
    switch srsStageCategory {
    case .apprentice:
      return UIColor(red: 0.87, green: 0.00, blue: 0.58, alpha: 1.0)
    case .guru:
      return UIColor(red: 0.53, green: 0.17, blue: 0.62, alpha: 1.0)
    case .master:
      return UIColor(red: 0.16, green: 0.30, blue: 0.86, alpha: 1.0)
    case .enlightened:
      return UIColor(red: 0.00, green: 0.58, blue: 0.87, alpha: 1.0)
    case .burned:
      return UIColor(red: 0.26, green: 0.26, blue: 0.26, alpha: 1.0)
    }
  }

  class func color2(forSubjectType subjectType: TKMSubject.TypeEnum) -> UIColor {
    switch subjectType {
    case .radical:
      return radicalColor2
    case .kanji:
      return kanjiColor2
    case .vocabulary:
      return vocabularyColor2
    default:
      fatalError()
    }
  }

  class func gradient(forAssignment assignment: TKMAssignment) -> [CGColor] {
    switch assignment.subjectType {
    case .radical:
      return radicalGradient
    case .kanji:
      return kanjiGradient
    case .vocabulary:
      return vocabularyGradient
    default:
      fatalError()
    }
  }

  class func gradient(forSubject subject: TKMSubject) -> [CGColor] {
    if subject.hasRadical {
      return radicalGradient
    } else if subject.hasKanji {
      return kanjiGradient
    } else if subject.hasVocabulary {
      return vocabularyGradient
    }
    return []
  }

  // MARK: - Japanese fonts

  static let japaneseFontName = "HiraginoSans-W3"
  static let japaneseFontNameBold = "HiraginoSans-W6"

  // MARK: - Dark mode aware UI colors

  enum Color {
    static let background = AdaptiveColor(light: UIColor.white, dark: UIColor.black)
    static let cellBackground = AdaptiveColorHex(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let separator = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.29)
    static let label = AdaptiveColor(light: UIColor.black, dark: UIColor.white)
    static let grey33 = AdaptiveColor(light: UIColor.darkGray, dark: UIColor.lightGray)
    static let grey66 = AdaptiveColor(light: UIColor.lightGray, dark: UIColor.darkGray)
    static let grey80 = AdaptiveColor(light: UIColor(white: 0.8, alpha: 1.0),
                                      dark: UIColor(white: 0.2, alpha: 1.0))

    // Markup colors for mnemonics.
    static let markupRadicalForeground = AdaptiveColorHex(light: 0x000000, dark: 0x4AC3FF)
    static let markupRadicalBackground = AdaptiveColorHex(light: 0xD6F1FF, dark: 0x1C1C1E)
    static let markupKanjiForeground = AdaptiveColorHex(light: 0x000000, dark: 0xFF4AC3)
    static let markupKanjiBackground = AdaptiveColorHex(light: 0xFFD6F1, dark: 0x1C1C1E)
    static let markupVocabularyForeground = AdaptiveColorHex(light: 0x000000, dark: 0xC34AFF)
    static let markupVocabularyBackground = AdaptiveColorHex(light: 0xF1D6FF, dark: 0x1C1C1E)

    static var placeholderText: UIColor {
      if #available(iOS 13.0, *) {
        return UIColor.placeholderText
      }
      return UIColor(red: 0, green: 0, blue: 0.0980392, alpha: 0.22)
    }
  }

  // Wrapper around UITraitCollection.performAsCurrent that just does nothing
  // on iOS < 13.
  class func withTraitCollection(_ tc: UITraitCollection, f: () -> Void) {
    if #available(iOS 13.0, *) {
      tc.performAsCurrent {
        f()
      }
    } else {
      f()
    }
  }
}
