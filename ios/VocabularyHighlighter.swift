// Copyright 2021 David Sansome
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

import Rexy

private class ConjugationGroup {
  public let prefix: String
  public let suffix: String
  public let pattern: String

  required init(prefix: String, suffix: String, conjugations: [String]) {
    self.prefix = prefix
    self.suffix = suffix

    let nonEmpty = conjugations.filter { str in !str.isEmpty }
    var pattern = "(" + nonEmpty.joined(separator: "|") + ")"
    if nonEmpty.count != conjugations.count {
      pattern += "?"
    }
    self.pattern = pattern
  }

  convenience init(suffix: String, conjugations: [String]) {
    self.init(prefix: "", suffix: suffix, conjugations: conjugations)
  }

  convenience init(prefix: String) {
    self.init(prefix: prefix, suffix: "", conjugations: [])
  }

  convenience init(suffix: String) {
    self.init(prefix: "", suffix: suffix, conjugations: [])
  }

  private class func verb(suffix: String,
                          te: String,
                          perfective: String,
                          negative: String,
                          continuous: String,
                          potential: String,
                          passive: String,
                          causative: String,
                          provisionalConditional: String,
                          imperative: String,
                          volitional: String,
                          cha: String,
                          extraConjugations: [String] = []) -> ConjugationGroup {
    ConjugationGroup(suffix: suffix, conjugations: [
      suffix,
      continuous,
      continuous + "ます",
      continuous + "たい",
      volitional + "う",
      suffix + "だろう",
      continuous + "ましょう",
      suffix + "でしょう",
      imperative,
      te,
      te + "ください",
      perfective,
      continuous + "ました",
      perfective + "ろう",
      perfective + "でしょう",
      te + "い(て|てい)?(る|て|た|ます|ました)",
      te + "る",
      te + "ます",
      te + "た",
      te + "ました",
      provisionalConditional + "ば",
      perfective + "ら",
      perfective + "らば",
      continuous + "ましたら",
      potential + "る",
      potential + "ます",
      causative + "せ(て|てい)?(る|て|た|ます|ました)",
      passive + "れ(て|てい)?(る|て|た|ます|ました)",
      causative + "せられ(て|てい)?(る|て|た|ます|ました)",

      negative + "ない",
      negative + "なかった",
      negative + "ぬ",
      continuous + "ません",
      continuous + "たくない",
      negative + "ないだろう",
      negative + "ぬだろう",
      negative + "ないでしょう",
      suffix + "な",
      negative + "ないでください",
      continuous + "ませんでした",
      negative + "なかっただろう",
      negative + "なかったでしょう",
      te + "いません(でした)?",
      te + "ません(でした)?",
      negative + "なければ",
      negative + "なきゃ",
      negative + "なくちゃ",
      negative + "なくなちゃった",
      negative + "なかったら",
      continuous + "ませんでしたら",
      potential + "ない",
      potential + "ません",
      causative + "せ(て|てい)?(ない|ないで|ません|ませんでした)",
      passive + "れ(て|てい)?(ない|ないで|ません|ませんでした)",
      causative + "せられ(て|てい)?(ない|ないで|ません|ませんでした)",

      te + "しまう",
      te + "しまった",
      te + "しまってた?",
      te + "しまいます",
      te + "しまいました",
      cha + "ゃう",
      cha + "ゃわない",
      cha + "ゃいます",
      cha + "ゃいません",
      cha + "ゃ",
      cha + "ゃった",
      cha + "ゃってた?",
      cha + "ゃわなかった",
      cha + "ゃわなくっ?て",
      cha + "ゃいました",
      cha + "ゃいませんでした",
    ] + extraConjugations)
  }

  class func godanVerb(_ a: String,
                       _ i: String,
                       _ u: String,
                       _ e: String,
                       _ o: String,
                       _ te: String,
                       _ ta: String,
                       _ cha: String) -> ConjugationGroup {
    verb(suffix: u,
         te: te,
         perfective: ta,
         negative: a,
         continuous: i,
         potential: e,
         passive: a,
         causative: a,
         provisionalConditional: e,
         imperative: e,
         volitional: o,
         cha: cha)
  }

  static var godanVerbs: [Character: ConjugationGroup] = [
    "う": godanVerb("わ", "い", "う", "え", "お", "って", "った", "っち"),
    "く": godanVerb("か", "き", "く", "け", "こ", "いて", "いた", "いち"),
    "ぐ": godanVerb("が", "ぎ", "ぐ", "げ", "ご", "いで", "いだ", "いじ"),
    "す": godanVerb("さ", "し", "す", "せ", "そ", "して", "した", "しち"),
    "つ": godanVerb("た", "ち", "つ", "て", "と", "って", "った", "っち"),
    "づ": godanVerb("だ", "ぢ", "づ", "で", "ど", "っで", "っだ", "っじ"),
    "ふ": godanVerb("は", "ひ", "ふ", "へ", "ほ", "んで", "んだ", "んじ"),
    "ぶ": godanVerb("ば", "び", "ぶ", "べ", "ぼ", "んで", "んだ", "んじ"),
    "む": godanVerb("ま", "み", "む", "め", "も", "んで", "んだ", "んじ"),
    "る": godanVerb("ら", "り", "る", "れ", "ろ", "って", "った", "っち"),
    "ぬ": godanVerb("な", "に", "ぬ", "ね", "の", "んで", "んだ", "んじ"),
  ]

  static var ichidanVerb = verb(suffix: "る",
                                te: "て",
                                perfective: "た",
                                negative: "",
                                continuous: "",
                                potential: "られ",
                                passive: "ら",
                                causative: "さ",
                                provisionalConditional: "れ",
                                imperative: "ろ",
                                volitional: "よ",
                                cha: "ち")

  static var suruVerb = verb(suffix: "する",
                             te: "して",
                             perfective: "した",
                             negative: "し",
                             continuous: "し",
                             potential: "せられ",
                             passive: "さ",
                             causative: "さ",
                             provisionalConditional: "すれ",
                             imperative: "しろ",
                             volitional: "しよ",
                             cha: "っち",
                             extraConjugations: [""] // Allow the suru verb stem by itself.
  )

  static var iAdjective = ConjugationGroup(suffix: "い",
                                           conjugations: [
                                             "",
                                             "い",
                                             "いです",
                                             "かった(です)?",
                                             "くない(です)?",
                                             "くなかった(です)?",
                                             "く",
                                             "くて",
                                             "ければ",
                                             "かろう",
                                           ])

  static var naAdjective = ConjugationGroup(suffix: "",
                                            conjugations: [
                                              "",
                                              "だ",
                                              "です",
                                              "な",
                                              "で",
                                              "だった",
                                              "でした",
                                              "でわない",
                                              "じゃない",
                                              "であれば",
                                              "だろう",
                                            ])

  public static func get(for subject: TKMSubject,
                         partOfSpeech: TKMVocabulary.PartOfSpeech) -> ConjugationGroup? {
    switch partOfSpeech {
    case .godanVerb:
      return godanVerbs[subject.japanese.last!]
    case .ichidanVerb:
      return ichidanVerb
    case .suruVerb:
      return suruVerb
    case .iAdjective:
      return iAdjective
    case .naAdjective:
      return naAdjective
    case .prefix, .adverb:
      return ConjugationGroup(suffix: "〜")
    case .suffix, .counter:
      return ConjugationGroup(prefix: "〜")
    default:
      return nil
    }
  }
}

func patternToHighlight(for subject: TKMSubject) -> String {
  // Always match the literal Japanese text.
  var patterns = [subject.japanese]

  for partOfSpeech in subject.vocabulary.partsOfSpeech {
    if let conjugationGroup = ConjugationGroup.get(for: subject, partOfSpeech: partOfSpeech) {
      // Strip the prefix and suffix strings.
      var japanese = subject.japanese
      if japanese.hasPrefix(conjugationGroup.prefix) {
        japanese = String(japanese.dropFirst(conjugationGroup.prefix.count))
      }
      if japanese.hasSuffix(conjugationGroup.suffix) {
        japanese = String(japanese.dropLast(conjugationGroup.suffix.count))
      }

      patterns.append(japanese + conjugationGroup.pattern)
    }
  }

  return "(" + patterns.joined(separator: "|") + ")"
}

func highlightOccurrences(of subject: TKMSubject,
                          in text: NSAttributedString) -> NSAttributedString? {
  if !subject.hasVocabulary {
    return nil
  }

  // We need to use Posix regular expressions (from the Rexy library) for guaranteed greedy longest-
  // possible matches.
  let pattern = patternToHighlight(for: subject)
  guard let re = try? Regex(pattern) else {
    NSLog("Invalid regex: %@", pattern)
    return nil
  }
  let matches = re.matches(text.string)
  if matches.isEmpty {
    return nil
  }

  let ret = NSMutableAttributedString(attributedString: text)
  for match in matches {
    let range = NSRange(match.startIndex ..< match.endIndex, in: text.string)
    ret.addAttribute(.foregroundColor, value: UIColor.systemRed, range: range)
  }

  return ret
}
