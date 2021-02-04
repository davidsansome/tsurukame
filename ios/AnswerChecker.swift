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

@objc class AnswerChecker: NSObject {
  @objc enum AnswerCheckerResult: Int {
    case Precise
    case Imprecise
    case OtherKanjiReading
    case ContainsInvalidCharacters
    case Incorrect
  }

  @objc static let kAsciiCharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0x00) ..< Unicode
    .Scalar(0x7F)!)
  @objc static let kHiraganaCharacterSet = CharacterSet(charactersIn: Unicode
    .Scalar(UInt32(0x3040))! ..< Unicode.Scalar(UInt32(0x309D))!)
  @objc static let kAllKanaCharacterSet = CharacterSet(charactersIn: Unicode
    .Scalar(UInt32(0x3040))! ..< Unicode.Scalar(UInt32(0x3100))!)
  @objc static let kJapaneseCharacterSet = kAllKanaCharacterSet
    .union(CharacterSet(charactersIn: Unicode.Scalar(UInt32(0x3400))! ..<
        Unicode.Scalar(UInt32(0x4DC0))!))
    .union(CharacterSet(charactersIn: Unicode.Scalar(UInt32(0x4E00))! ..<
        Unicode.Scalar(UInt32(0xA000))!))
    .union(CharacterSet(charactersIn: Unicode.Scalar(UInt32(0xF900))! ..<
        Unicode.Scalar(UInt32(0xFB00))!))
    .union(CharacterSet(charactersIn: Unicode.Scalar(UInt32(0xFF66))! ..<
        Unicode.Scalar(UInt32(0xFFA0))!))

  private class func containsAscii(_ s: String) -> Bool {
    s.rangeOfCharacter(from: kAsciiCharacterSet) != nil
  }

  private class func isKana(_ s: String) -> Bool {
    s.rangeOfCharacter(from: kAllKanaCharacterSet.inverted) == nil
  }

  private class func isJapanese(_ s: String) -> Bool {
    s.rangeOfCharacter(from: kJapaneseCharacterSet.inverted) == nil
  }

  private class func distanceTolerance(_ answer: String) -> Int {
    if answer.count <= 3 {
      return 0
    }
    if answer.count <= 5 {
      return 1
    }
    if answer.count <= 7 {
      return 2
    }
    return Int(2 + 1 * floor(Double(answer.count) / 7))
  }

  private class func mismatchingOkurigana(answer: String, japanese: String) -> Bool {
    if answer.unicodeScalars.count < japanese.unicodeScalars.count {
      return false
    }

    for (japaneseChar, answerChar) in zip(japanese.unicodeScalars,
                                          answer.unicodeScalars) {
      if !kHiraganaCharacterSet.contains(japaneseChar) {
        break
      }
      if japaneseChar != answerChar {
        return true
      }
    }

    for (japaneseChar, answerChar) in zip(japanese.unicodeScalars.reversed(),
                                          answer.unicodeScalars.reversed()) {
      if !kHiraganaCharacterSet.contains(japaneseChar) {
        break
      }
      if japaneseChar != answerChar {
        return true
      }
    }

    return false
  }

  public class func convertKatakanaToHiragana(_ text: String) -> String {
    // StringTransform.hiraganaToKatakana munges long-dashes so we need to special case strings that
    // contain those.
    if let dash = text.firstIndex(of: "ー") {
      return convertKatakanaToHiragana(String(text[..<dash])) +
        "ー" +
        convertKatakanaToHiragana(String(text[text.index(after: dash)...]))
    }

    return text.applyingTransform(StringTransform.hiraganaToKatakana, reverse: true)!
  }

  class func normalizedString(_ text: String, taskType: TaskType,
                              alphabet: TKMAlphabet = TKMAlphabet.hiragana) -> String {
    var s =
      text.trimmingCharacters(in: CharacterSet.whitespaces)
        .lowercased()
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: ".", with: "")
        .replacingOccurrences(of: "'", with: "")
        .replacingOccurrences(of: "/", with: "")
    if taskType == .reading {
      s = s.replacingOccurrences(of: "n", with: alphabet == TKMAlphabet.hiragana ? "ん" : "ン")

      // Gboard Godan layout uses "ｎ" or Unicode code point U+FF4E.
      s = s.replacingOccurrences(of: "ｎ", with: alphabet == TKMAlphabet.hiragana ? "ん" : "ン")

      s = s.replacingOccurrences(of: " ", with: "")
    }
    return s
  }

  class func checkAnswer(_ answer: String,
                         subject: TKMSubject,
                         studyMaterials: TKMStudyMaterials?,
                         taskType: TaskType,
                         localCachingClient: LocalCachingClient) -> AnswerCheckerResult {
    switch taskType {
    case .reading:
      let hiraganaText = convertKatakanaToHiragana(answer)

      if !isKana(answer) {
        return .ContainsInvalidCharacters
      }

      for reading in subject.primaryReadings {
        if reading.reading == hiraganaText {
          return .Precise
        }
      }
      for reading in subject.alternateReadings {
        if reading.reading == hiraganaText {
          return subject.hasKanji ? .OtherKanjiReading : .Precise
        }
      }
      if subject.hasVocabulary, subject.japanese.count == 1,
        subject.componentSubjectIds.count == 1 {
        // If the vocabulary is made up of only one Kanji, check whether the user wrote the Kanji
        // reading instead of the vocabulary reading.
        if let kanji = localCachingClient
          .getSubject(id: subject.componentSubjectIds[0]) {
          let result = checkAnswer(answer, subject: kanji, studyMaterials: nil, taskType: taskType,
                                   localCachingClient: localCachingClient)
          if result == .Precise {
            return .OtherKanjiReading
          }
        }
      }
      if subject.hasVocabulary, mismatchingOkurigana(answer: answer, japanese: subject.japanese) {
        return .OtherKanjiReading
      }

    case .meaning:
      if isJapanese(answer) {
        return .ContainsInvalidCharacters
      }

      // Check blacklisted meanings first.  If the answer matches one exactly, it's incorrect.
      for meaning in subject.meanings {
        if meaning.type == .blacklist {
          if normalizedString(meaning.meaning, taskType: taskType) == answer {
            return .Incorrect
          }
        }
      }

      // Gather all possible meanings from synonyms and from the subject itself.
      var meaningTexts = [String]()
      if let studyMaterials = studyMaterials {
        meaningTexts.append(contentsOf: studyMaterials.meaningSynonyms)
      }

      for meaning in subject.meanings {
        if meaning.type != .blacklist {
          meaningTexts.append(meaning.meaning)
        }
      }

      for meaning in meaningTexts {
        if normalizedString(meaning, taskType: taskType) == answer {
          return .Precise
        }
      }
      for meaning in meaningTexts {
        let meaningText = normalizedString(meaning, taskType: taskType)
        let distance = meaningText.levenshteinDistance(to: answer)
        let tolerance = distanceTolerance(meaningText)
        if Int(distance) <= tolerance {
          return .Imprecise
        }
      }
    }

    return .Incorrect
  }
}
