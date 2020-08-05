// Copyright 2020 David Sansome
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

@objc enum TKMAlphabet: UInt, Codable {
  case hiragana = 0, katakana = 1
}

@objcMembers class KanaInput: NSObject, UITextFieldDelegate {
  private weak var delegate: UITextFieldDelegate?
  var enabled = true, alphabet: TKMAlphabet = .hiragana
  static let replacements: [String: String] = [
    "a": "\u{3042}",
    "ba": "\u{3070}",
    "be": "\u{3079}",
    "bi": "\u{3073}",
    "bo": "\u{307c}",
    "bu": "\u{3076}",
    "bya": "\u{3073}\u{3083}",
    "bye": "\u{3073}\u{3047}",
    "byi": "\u{3073}\u{3043}",
    "byo": "\u{3073}\u{3087}",
    "byu": "\u{3073}\u{3085}",
    "ca": "\u{304b}",
    "ce": "\u{3051}",
    "cha": "\u{3061}\u{3083}",
    "che": "\u{3061}\u{3047}",
    "chi": "\u{3061}",
    "cho": "\u{3061}\u{3087}",
    "chu": "\u{3061}\u{3085}",
    "chya": "\u{3061}\u{3083}",
    "chye": "\u{3061}\u{3047}",
    "chyo": "\u{3061}\u{3087}",
    "chyu": "\u{3061}\u{3085}",
    "ci": "\u{304d}",
    "co": "\u{3053}",
    "cu": "\u{304f}",
    "cya": "\u{3061}\u{3083}",
    "cye": "\u{3061}\u{3047}",
    "cyi": "\u{3061}\u{3043}",
    "cyo": "\u{3061}\u{3087}",
    "cyu": "\u{3061}\u{3085}",
    "da": "\u{3060}",
    "de": "\u{3067}",
    "dha": "\u{3067}\u{3083}",
    "dhe": "\u{3067}\u{3047}",
    "dhi": "\u{3067}\u{3043}",
    "dho": "\u{3067}\u{3087}",
    "dhu": "\u{3067}\u{3085}",
    "di": "\u{3062}",
    "do": "\u{3069}",
    "du": "\u{3065}",
    "dwa": "\u{3069}\u{3041}",
    "dwe": "\u{3069}\u{3047}",
    "dwi": "\u{3069}\u{3043}",
    "dwo": "\u{3069}\u{3049}",
    "dwu": "\u{3069}\u{3045}",
    "dya": "\u{3062}\u{3083}",
    "dye": "\u{3062}\u{3047}",
    "dyi": "\u{3062}\u{3043}",
    "dyo": "\u{3062}\u{3087}",
    "dyu": "\u{3062}\u{3085}",
    "e": "\u{3048}",
    "fa": "\u{3075}\u{3041}",
    "fe": "\u{3075}\u{3047}",
    "fi": "\u{3075}\u{3043}",
    "fo": "\u{3075}\u{3049}",
    "fu": "\u{3075}",
    "fwa": "\u{3075}\u{3041}",
    "fwe": "\u{3075}\u{3047}",
    "fwi": "\u{3075}\u{3043}",
    "fwo": "\u{3075}\u{3049}",
    "fwu": "\u{3075}\u{3045}",
    "fya": "\u{3075}\u{3083}",
    "fye": "\u{3075}\u{3047}",
    "fyi": "\u{3075}\u{3043}",
    "fyo": "\u{3075}\u{3087}",
    "fyu": "\u{3075}\u{3085}",
    "ga": "\u{304c}",
    "ge": "\u{3052}",
    "gi": "\u{304e}",
    "go": "\u{3054}",
    "gu": "\u{3050}",
    "gwa": "\u{3050}\u{3041}",
    "gwe": "\u{3050}\u{3047}",
    "gwi": "\u{3050}\u{3043}",
    "gwo": "\u{3050}\u{3049}",
    "gwu": "\u{3050}\u{3045}",
    "gya": "\u{304e}\u{3083}",
    "gye": "\u{304e}\u{3047}",
    "gyi": "\u{304e}\u{3043}",
    "gyo": "\u{304e}\u{3087}",
    "gyu": "\u{304e}\u{3085}",
    "ha": "\u{306f}",
    "he": "\u{3078}",
    "hi": "\u{3072}",
    "ho": "\u{307b}",
    "hu": "\u{3075}",
    "hya": "\u{3072}\u{3083}",
    "hye": "\u{3072}\u{3047}",
    "hyi": "\u{3072}\u{3043}",
    "hyo": "\u{3072}\u{3087}",
    "hyu": "\u{3072}\u{3085}",
    "i": "\u{3044}",
    "ja": "\u{3058}\u{3083}",
    "je": "\u{3058}\u{3047}",
    "ji": "\u{3058}",
    "jo": "\u{3058}\u{3087}",
    "ju": "\u{3058}\u{3085}",
    "jya": "\u{3058}\u{3083}",
    "jye": "\u{3058}\u{3047}",
    "jyi": "\u{3058}\u{3043}",
    "jyo": "\u{3058}\u{3087}",
    "jyu": "\u{3058}\u{3085}",
    "ka": "\u{304b}",
    "ke": "\u{3051}",
    "ki": "\u{304d}",
    "ko": "\u{3053}",
    "ku": "\u{304f}",
    "kwa": "\u{304f}\u{3041}",
    "kya": "\u{304d}\u{3083}",
    "kye": "\u{304d}\u{3047}",
    "kyi": "\u{304d}\u{3043}",
    "kyo": "\u{304d}\u{3087}",
    "kyu": "\u{304d}\u{3085}",
    "la": "\u{3089}",
    "lca": "\u{30f5}",
    "lce": "\u{30f6}",
    "le": "\u{308c}",
    "li": "\u{308a}",
    "lka": "\u{30f5}",
    "lke": "\u{30f6}",
    "lo": "\u{308d}",
    "ltsu": "\u{3063}",
    "ltu": "\u{3063}",
    "lu": "\u{308b}",
    "lwe": "\u{308e}",
    "lya": "\u{308a}\u{3083}",
    "lye": "\u{308a}\u{3047}",
    "lyi": "\u{308a}\u{3043}",
    "lyo": "\u{308a}\u{3087}",
    "lyu": "\u{308a}\u{3085}",
    "ma": "\u{307e}",
    "me": "\u{3081}",
    "mi": "\u{307f}",
    "mo": "\u{3082}",
    "mu": "\u{3080}",
    "mya": "\u{307f}\u{3083}",
    "mye": "\u{307f}\u{3047}",
    "myi": "\u{307f}\u{3043}",
    "myo": "\u{307f}\u{3087}",
    "myu": "\u{307f}\u{3085}",
    "n ": "\u{3093}",
    "na": "\u{306a}",
    "ne": "\u{306d}",
    "ni": "\u{306b}",
    "nn": "\u{3093}",
    "no": "\u{306e}",
    "nu": "\u{306c}",
    "nya": "\u{306b}\u{3083}",
    "nye": "\u{306b}\u{3047}",
    "nyi": "\u{306b}\u{3043}",
    "nyo": "\u{306b}\u{3087}",
    "nyu": "\u{306b}\u{3085}",
    "o": "\u{304a}",
    "pa": "\u{3071}",
    "pe": "\u{307a}",
    "pi": "\u{3074}",
    "po": "\u{307d}",
    "pu": "\u{3077}",
    "pya": "\u{3074}\u{3083}",
    "pye": "\u{3074}\u{3047}",
    "pyi": "\u{3074}\u{3043}",
    "pyo": "\u{3074}\u{3087}",
    "pyu": "\u{3074}\u{3085}",
    "qa": "\u{304f}\u{3041}",
    "qe": "\u{304f}\u{3047}",
    "qi": "\u{304f}\u{3043}",
    "qo": "\u{304f}\u{3049}",
    "qwa": "\u{304f}\u{3041}",
    "qwe": "\u{304f}\u{3047}",
    "qwi": "\u{304f}\u{3043}",
    "qwo": "\u{304f}\u{3049}",
    "qwu": "\u{304f}\u{3045}",
    "qya": "\u{304f}\u{3083}",
    "qye": "\u{304f}\u{3047}",
    "qyi": "\u{304f}\u{3043}",
    "qyo": "\u{304f}\u{3087}",
    "qyu": "\u{304f}\u{3085}",
    "ra": "\u{3089}",
    "re": "\u{308c}",
    "ri": "\u{308a}",
    "ro": "\u{308d}",
    "ru": "\u{308b}",
    "rya": "\u{308a}\u{3083}",
    "rye": "\u{308a}\u{3047}",
    "ryi": "\u{308a}\u{3043}",
    "ryo": "\u{308a}\u{3087}",
    "ryu": "\u{308a}\u{3085}",
    "sa": "\u{3055}",
    "se": "\u{305b}",
    "sha": "\u{3057}\u{3083}",
    "she": "\u{3057}\u{3047}",
    "shi": "\u{3057}",
    "sho": "\u{3057}\u{3087}",
    "shu": "\u{3057}\u{3085}",
    "shya": "\u{3057}\u{3083}",
    "shye": "\u{3057}\u{3047}",
    "shyo": "\u{3057}\u{3087}",
    "shyu": "\u{3057}\u{3085}",
    "si": "\u{3057}",
    "so": "\u{305d}",
    "su": "\u{3059}",
    "swa": "\u{3059}\u{3041}",
    "swe": "\u{3059}\u{3047}",
    "swi": "\u{3059}\u{3043}",
    "swo": "\u{3059}\u{3049}",
    "swu": "\u{3059}\u{3045}",
    "sya": "\u{3057}\u{3083}",
    "sye": "\u{3057}\u{3047}",
    "syi": "\u{3057}\u{3043}",
    "syo": "\u{3057}\u{3087}",
    "syu": "\u{3057}\u{3085}",
    "ta": "\u{305f}",
    "te": "\u{3066}",
    "tha": "\u{3066}\u{3083}",
    "the": "\u{3066}\u{3047}",
    "thi": "\u{3066}\u{3043}",
    "tho": "\u{3066}\u{3087}",
    "thu": "\u{3066}\u{3085}",
    "ti": "\u{3061}",
    "to": "\u{3068}",
    "tsa": "\u{3064}\u{3041}",
    "tse": "\u{3064}\u{3047}",
    "tsi": "\u{3064}\u{3043}",
    "tso": "\u{3064}\u{3049}",
    "tsu": "\u{3064}",
    "tu": "\u{3064}",
    "twa": "\u{3068}\u{3041}",
    "twe": "\u{3068}\u{3047}",
    "twi": "\u{3068}\u{3043}",
    "two": "\u{3068}\u{3049}",
    "twu": "\u{3068}\u{3045}",
    "tya": "\u{3061}\u{3083}",
    "tye": "\u{3061}\u{3047}",
    "tyi": "\u{3061}\u{3043}",
    "tyo": "\u{3061}\u{3087}",
    "tyu": "\u{3061}\u{3085}",
    "u": "\u{3046}",
    "va": "\u{3094}\u{3041}",
    "ve": "\u{3094}\u{3047}",
    "vi": "\u{3094}\u{3043}",
    "vo": "\u{3094}\u{3049}",
    "vu": "\u{3094}",
    "vya": "\u{3094}\u{3083}",
    "vye": "\u{3094}\u{3047}",
    "vyi": "\u{3094}\u{3043}",
    "vyo": "\u{3094}\u{3087}",
    "vyu": "\u{3094}\u{3085}",
    "wa": "\u{308f}",
    "we": "\u{3046}\u{3047}",
    "wha": "\u{3046}\u{3041}",
    "whe": "\u{3046}\u{3047}",
    "whi": "\u{3046}\u{3043}",
    "who": "\u{3046}\u{3049}",
    "whu": "\u{3046}",
    "wi": "\u{3046}\u{3043}",
    "wo": "\u{3092}",
    "wu": "\u{3046}",
    "xa": "\u{3041}",
    "xca": "\u{30f5}",
    "xce": "\u{30f6}",
    "xe": "\u{3047}",
    "xi": "\u{3043}",
    "xka": "\u{30f5}",
    "xke": "\u{30f6}",
    "xn": "\u{3093}",
    "xo": "\u{3049}",
    "xtu": "\u{3063}",
    "xu": "\u{3045}",
    "xwa": "\u{308e}",
    "xya": "\u{3083}",
    "xye": "\u{3047}",
    "xyi": "\u{3043}",
    "xyo": "\u{3087}",
    "xyu": "\u{3085}",
    "ya": "\u{3084}",
    "ye": "\u{3044}\u{3047}",
    "yi": "\u{3044}",
    "yo": "\u{3088}",
    "yu": "\u{3086}",
    "za": "\u{3056}",
    "ze": "\u{305c}",
    "zi": "\u{3058}",
    "zo": "\u{305e}",
    "zu": "\u{305a}",
    "zya": "\u{3058}\u{3083}",
    "zye": "\u{3058}\u{3047}",
    "zyi": "\u{3058}\u{3043}",
    "zyo": "\u{3058}\u{3087}",
    "zyu": "\u{3058}\u{3085}",
    "-": "\u{30fc}",
  ]
  static let consonants: CharacterSet = CharacterSet(charactersIn: "bcdfghjklmnpqrstvwxyz")
  static let n: CharacterSet = CharacterSet(charactersIn: "nm")
  static let canFollowN: CharacterSet = CharacterSet(charactersIn: "aiueony")

  required init(delegate: UITextFieldDelegate) {
    super.init()
    self.delegate = delegate
  }

  static func convertKanaText(input: String) -> String {
    var ret: String.UnicodeScalarView = input.unicodeScalars
    for i in 0 ..< ret.count {
      if i > 0 {
        let currentChar: UnicodeScalar = ret[ret.index(ret.startIndex, offsetBy: i)]
        let prevChar: UnicodeScalar = ret[ret.index(ret.startIndex, offsetBy: i - 1)]
        if currentChar != "n", currentChar == prevChar, consonants.contains(prevChar) {
          ret.remove(at: ret.index(ret.startIndex, offsetBy: i - 1))
          ret.insert("\u{3063}", at: ret.index(ret.startIndex, offsetBy: i - 1))
        }
      }

      // Test for replacements.
      for len in (1 ... 4).reversed() {
        if len > i + 1 { continue }
        let replacementRange = ret.index(ret.startIndex, offsetBy: i - len + 1) ...
          ret.index(ret.startIndex, offsetBy: i)
        let text = String(String(ret)[replacementRange])
        if let replacement = replacements[text] {
          var temp = String(ret)
          temp.replaceSubrange(replacementRange, with: replacement)
          ret = temp.unicodeScalars
          break
        }
      }
    }

    // Replace n and remove anything that isn't kana
    for i in 0 ..< ret.count {
      if n.contains(ret[ret.index(ret.startIndex, offsetBy: i)]) {
        ret.remove(at: ret.index(ret.startIndex, offsetBy: i))
        ret.insert("\u{3093}", at: ret.index(ret.startIndex, offsetBy: i))
      }
    }
    for i in (0 ..< ret.count).reversed() {
      if CharacterSet.lowercaseLetters.contains(ret[ret.index(ret.startIndex, offsetBy: i)]) {
        ret.remove(at: ret.index(ret.startIndex, offsetBy: i))
      } else { break }
    }
    return String(ret)
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    _ = delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string)
    if !enabled || range.length != 0 || string.count == 0 { return true }

    if range.location > 0, string.count == 1 {
      let string: String.UnicodeScalarView = string.unicodeScalars
      var newChar: UnicodeScalar = string.first!, text = textField.text!.unicodeScalars
      var prevChar: UnicodeScalar = text[text.index(text.startIndex, offsetBy: range.location - 1)]
      let lastCharUpper = CharacterSet.uppercaseLetters.contains(prevChar)

      newChar = String(newChar).lowercased().unicodeScalars.first!
      prevChar = String(prevChar).lowercased().unicodeScalars.first!

      // Test for sokuon.
      if !KanaInput.n.contains(newChar), newChar == prevChar,
        KanaInput.consonants.contains(newChar),
        KanaInput.consonants.contains(prevChar) {
        let replacementChar: Character = (lastCharUpper || alphabet == .katakana) ? "\u{30C3}" :
          "\u{3063}"
        let replacementIndex = textField.text!.index(textField.text!.startIndex,
                                                     offsetBy: range.location - 1)
        textField.text!.remove(at: replacementIndex)
        textField.text!.insert(replacementChar, at: replacementIndex)
        return true
      }

      // Replace n followed by a consonant.
      if newChar != "n", KanaInput.n.contains(prevChar), !KanaInput.canFollowN.contains(newChar) {
        let replacementChar: Character = (lastCharUpper || alphabet == .katakana) ? "\u{30F3}" :
          "\u{3093}"
        let replacementIndex = textField.text!.index(textField.text!.startIndex,
                                                     offsetBy: range.location - 1)
        textField.text!.remove(at: replacementIndex)
        textField.text!.insert(replacementChar, at: replacementIndex)
        return true
      }
    }
    // Test for replacements.
    for i in (0 ... 3).reversed() {
      if i > range.location { continue }
      let replacementRange = textField.text!.index(textField.text!.startIndex,
                                                   offsetBy: range.location - i) ..<
        textField.text!.index(textField.text!.startIndex, offsetBy: i)
      var text = "\(textField.text![replacementRange])\(string)"
      let firstCharUpper = CharacterSet.uppercaseLetters.contains(text.unicodeScalars.first!)
      text = text.lowercased()

      if let replacement = KanaInput.replacements[text] {
        var replacementString: String = replacement
        if firstCharUpper || alphabet == .katakana {
          replacementString = replacement.applyingTransform(StringTransform.hiraganaToKatakana,
                                                            reverse: false)!
        }
        var text: String = textField.text!
        text.replaceSubrange(replacementRange, with: replacementString)
        textField.text = text
        return false
      }
    }
    return true
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    delegate!.textFieldShouldReturn!(textField)
  }
}
