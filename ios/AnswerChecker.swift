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

class AnswerChecker: NSObject {
  enum AnswerCheckerResult: Equatable {
    case Precise
    case Imprecise
    case OtherKanjiReading
    case MismatchingOkurigana([NSRange])
    case ContainsInvalidCharacters([NSRange])
    case IsReadingButWantMeaning
    case Incorrect
  }

  static let kAsciiCharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0x00) ..< Unicode
    .Scalar(0x7F)!)
  static let kHiraganaCharacterSet = CharacterSet(charactersIn: Unicode
    .Scalar(UInt32(0x3040))! ..< Unicode.Scalar(UInt32(0x309D))!)
  static let kAllKanaCharacterSet = CharacterSet(charactersIn: Unicode
    .Scalar(UInt32(0x3040))! ..< Unicode.Scalar(UInt32(0x3100))!)
  static let kJapaneseCharacterSet = kAllKanaCharacterSet
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

  private class func findNonKanaRanges(_ s: String) -> [NSRange] {
    findCharacterRanges(in: s, from: kAllKanaCharacterSet.inverted)
  }

  private class func findJapaneseRanges(_ s: String) -> [NSRange] {
    findCharacterRanges(in: s, from: kJapaneseCharacterSet)
  }

  private class func findCharacterRanges(in s: String, from: CharacterSet) -> [NSRange] {
    var ret = [NSRange]()

    var start: Int?
    var length = 0

    for (index, c) in s.unicodeScalars.enumerated() {
      if from.contains(c) {
        if start == nil {
          start = index
        }
        length += 1
      } else {
        if start != nil {
          ret.append(NSMakeRange(start!, length))
          start = nil
          length = 0
        }
      }
    }

    if let start = start {
      ret.append(NSMakeRange(start, length))
    }

    return ret
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

  private class func mismatchingOkurigana(answer: String, japanese: String) -> [NSRange] {
    if answer.unicodeScalars.count < japanese.unicodeScalars.count {
      return []
    }

    var ret = [NSRange]()

    if let prefixRange = mismatchingOkurigana(answer: answer.unicodeScalars,
                                              japanese: japanese.unicodeScalars) {
      ret.append(prefixRange)
    }

    if let suffixRange = mismatchingOkurigana(answer: answer.unicodeScalars.reversed(),
                                              japanese: japanese.unicodeScalars.reversed()) {
      // Reverse the range again to match the original string.
      ret.append(NSMakeRange(answer.count - suffixRange.lowerBound - suffixRange.length,
                             suffixRange.length))
    }

    return ret
  }

  private class func mismatchingOkurigana<T: Collection<Unicode.Scalar>>(answer: T,
                                                                         japanese: T) -> NSRange? {
    var mismatchingRangeBegin: Int?
    var mismatchingRangeEnd: Int?

    for (index, (japaneseChar, answerChar)) in zip(japanese, answer).enumerated() {
      if !kHiraganaCharacterSet.contains(japaneseChar) {
        break
      }
      if japaneseChar != answerChar {
        mismatchingRangeBegin = min(index, mismatchingRangeBegin ?? index)
        mismatchingRangeEnd = max(index, mismatchingRangeEnd ?? index)
      }
    }

    if let begin = mismatchingRangeBegin, let end = mismatchingRangeEnd {
      return NSMakeRange(begin, end - begin + 1)
    }
    return nil
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

      let nonKanaRanges = findNonKanaRanges(answer)
      if !nonKanaRanges.isEmpty {
        return .ContainsInvalidCharacters(nonKanaRanges)
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
      if subject.hasVocabulary {
        let ranges = mismatchingOkurigana(answer: answer,
                                          japanese: subject.japanese)
        if !ranges.isEmpty {
          return .MismatchingOkurigana(ranges)
        }
      }

    case .meaning:
      let japaneseRanges = findJapaneseRanges(answer)
      if !japaneseRanges.isEmpty {
        return .ContainsInvalidCharacters(japaneseRanges)
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

      // Check if the answer matches a meaning exactly.
      for meaning in meaningTexts {
        if normalizedString(meaning, taskType: taskType) == answer {
          return .Precise
        }
      }

      // Check if the answer *almost* matches a meaning.
      for meaning in meaningTexts {
        let meaningText = normalizedString(meaning, taskType: taskType)
        let distance = meaningText.levenshteinDistance(to: answer)
        let tolerance = distanceTolerance(meaningText)
        if Int(distance) <= tolerance {
          return .Imprecise
        }
      }

      // Check if the answer would match one of the readings if converted to hiragana.
      let kanaText = TKMConvertKanaText(answer)
      switch checkAnswer(kanaText, subject: subject, studyMaterials: studyMaterials,
                         taskType: .reading, localCachingClient: localCachingClient) {
      case .Precise, .Imprecise, .OtherKanjiReading:
        return .IsReadingButWantMeaning
      default:
        break
      }
    }

    return .Incorrect
  }
}
