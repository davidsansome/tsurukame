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

  // Shu (vermilion) — the red crown of the tanchō crane. The app's single accent colour.
  static let defaultTintColor = AdaptiveColorHex(light: 0xC8402B, dark: 0xD9533D)

  // Subject colours are flat (both "gradient" stops are the same) and deep enough for white
  // text at 5:1 or better.
  static let radicalColor1 = AdaptiveColorHex(light: 0x2B6CB0, dark: 0x2A64A3)
  static let radicalColor2 = radicalColor1
  static let kanjiColor1 = AdaptiveColorHex(light: 0xB8346B, dark: 0xA82E62)
  static let kanjiColor2 = kanjiColor1
  static let vocabularyColor1 = AdaptiveColorHex(light: 0x74409F, dark: 0x6A3A96)
  static let vocabularyColor2 = vocabularyColor1
  static let lockedColor1 = UIColorFromHex(0x5F574B)
  static let lockedColor2 = lockedColor1
  // The review prompt strip: ink for readings, paper for meanings.
  static let readingColor1 = AdaptiveColorHex(light: 0x1F1D1A, dark: 0x2E2B26)
  static let readingColor2 = readingColor1
  static let meaningColor1 = AdaptiveColorHex(light: 0xFFFCF6, dark: 0xE9E1D2)
  static let meaningColor2 = meaningColor1

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
      return AdaptiveColorHex(light: 0xB8346B, dark: 0xE0678F)
    case .guru:
      return AdaptiveColorHex(light: 0x74409F, dark: 0xB083D6)
    case .master:
      return AdaptiveColorHex(light: 0x2F55B5, dark: 0x7D98E0)
    case .enlightened:
      return AdaptiveColorHex(light: 0x2F7FB5, dark: 0x6FB3E0)
    case .burned:
      return AdaptiveColorHex(light: 0x3A3631, dark: 0xF2ECDF)
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
    // Washi paper and sumi ink. Dark mode swaps them for warm near-black and off-white.
    static let background = AdaptiveColorHex(light: 0xF5EFE3, dark: 0x161512)
    static let cellBackground = AdaptiveColorHex(light: 0xFFFCF6, dark: 0x211F1B)
    static let separator = AdaptiveColorHex(light: 0xEEE6D6, dark: 0x2C2924)
    static let cardBorder = AdaptiveColorHex(light: 0xE6DCC9, dark: 0x2E2B26)
    static let label = AdaptiveColorHex(light: 0x1F1D1A, dark: 0xF2ECDF)
    static let grey33 = AdaptiveColorHex(light: 0x5F574B, dark: 0xABA290)
    static let grey66 = AdaptiveColorHex(light: 0xB9AE99, dark: 0x6E665A)
    static let grey80 = AdaptiveColorHex(light: 0xE0D5C1, dark: 0x3A3630)
    static let accent = TKMStyle.defaultTintColor
    // Night indigo, used behind the waves on the home screen's Reviews card.
    static let night = UIColorFromHex(0x1B2740)
    static let onNight = UIColorFromHex(0xF5EFE3)
    static let onNightSecondary = UIColorFromHex(0xC9C1B1)

    // Markup colors for mnemonics.
    static let markupRadicalForeground = label
    static let markupRadicalBackground = AdaptiveColorHex(light: 0xDCE8F5, dark: 0x24364D)
    static let markupKanjiForeground = label
    static let markupKanjiBackground = AdaptiveColorHex(light: 0xF7E4EC, dark: 0x45283A)
    static let markupVocabularyForeground = label
    static let markupVocabularyBackground = AdaptiveColorHex(light: 0xEEE5F5, dark: 0x3A2D47)

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
