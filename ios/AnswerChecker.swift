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

@objc class AnswerChecker: NSObject {
  @objc enum AnswerCheckerResult: Int {
    case Precise
    case Imprecise
    case OtherKanjiReading
    case ContainsInvalidCharacters
    case Incorrect
  }

  @objc static let kAsciiCharacterSet = CharacterSet(charactersIn: Unicode.Scalar(0) ..< Unicode.Scalar(UInt32(256))!)

  @objc static let kKanaCharacterSet = CharacterSet(charactersIn:
    "あいうえお" +
      "かきくけこがぎぐげご" +
      "さしすせそざじずぜぞ" +
      "たちつてとだぢづでど" +
      "なにぬねの" +
      "はひふへほばびぶべぼぱぴぷぺぽ" +
      "まみむめも" +
      "らりるれろ" +
      "やゆよゃゅょぃっ" +
      "わをん")

  private class func containsAscii(_ s: String) -> Bool {
    return s.rangeOfCharacter(from: kAsciiCharacterSet) != nil
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
      if !kKanaCharacterSet.contains(japaneseChar) {
        break
      }
      if japaneseChar != answerChar {
        return true
      }
    }

    for (japaneseChar, answerChar) in zip(japanese.unicodeScalars.reversed(),
                                          answer.unicodeScalars.reversed()) {
      if !kKanaCharacterSet.contains(japaneseChar) {
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

  @objc class func normalizedString(_ text: String, taskType: TKMTaskType,
                                    alphabet: TKMAlphabet = TKMAlphabet.hiragana) -> String {
    var s =
      text.trimmingCharacters(in: CharacterSet.whitespaces)
      .lowercased()
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: "'", with: "")
      .replacingOccurrences(of: "/", with: "")
    if taskType == TKMTaskType.reading {
      s = s.replacingOccurrences(of: "n", with: alphabet == TKMAlphabet.hiragana ? "ん" : "ン")
      s = s.replacingOccurrences(of: " ", with: "")
    }
    return s
  }

  @objc class func checkAnswer(_ answer: String,
                               subject: TKMSubject,
                               studyMaterials: TKMStudyMaterials?,
                               taskType: TKMTaskType,
                               dataLoader: DataLoader) -> AnswerCheckerResult {
    switch taskType {
    case .reading:
      let hiraganaText = convertKatakanaToHiragana(answer)

      if containsAscii(answer) {
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
        subject.componentSubjectIdsArray_Count == 1 {
        // If the vocabulary is made up of only one Kanji, check whether the user wrote the Kanji
        // reading instead of the vocabulary reading.
        if let kanji = dataLoader.load(subjectID: Int(subject.componentSubjectIdsArray!.value(at: 0))) {
          let result = checkAnswer(answer, subject: kanji, studyMaterials: nil, taskType: taskType, dataLoader: dataLoader)
          if result == .Precise {
            return .OtherKanjiReading
          }
        }
      }
      if subject.hasVocabulary, mismatchingOkurigana(answer: answer, japanese: subject.japanese) {
        return .OtherKanjiReading
      }

    case .meaning:
      // Check blacklisted meanings first.  If the answer matches one exactly, it's incorrect.
      for meaning in subject.meaningsArray! as! [TKMMeaning] {
        if meaning.type == .blacklist {
          if normalizedString(meaning.meaning, taskType: taskType) == answer {
            return .Incorrect
          }
        }
      }

      // Gather all possible meanings from synonyms and from the subject itself.
      var meaningTexts = [String]()
      if let studyMaterials = studyMaterials {
        meaningTexts.append(contentsOf: studyMaterials.meaningSynonymsArray as! [String])
      }

      for meaning in subject.meaningsArray! as! [TKMMeaning] {
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

    case ._Max:
      fallthrough
    @unknown default:
      fatalError()
    }

    return .Incorrect
  }
}
