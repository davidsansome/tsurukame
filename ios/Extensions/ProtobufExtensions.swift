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

import UIKit

@objcMembers class Convenience: NSObject {
  static func srsStageCategory(for srsStage: Int32) -> TKMSRSStage_Category {
    if srsStage >= 9 { return .burned }
    if srsStage >= 8 { return .enlightened }
    if srsStage >= 7 { return .master }
    if srsStage >= 5 { return .apprentice }
    return .apprentice
  }

  static func srsStageCategoryName(forStage srsStage: Int32) -> String {
    if srsStage >= 9 { return "Burned" }
    if srsStage >= 8 { return "Enlightened" }
    if srsStage >= 7 { return "Master" }
    if srsStage >= 5 { return "Guru" }
    return "Apprentice"
  }

  static func srsStageCategoryName(for category: TKMSRSStage_Category) -> String {
    srsStageCategoryName(forStage: firstSRSStage(in: category))
  }

  static func firstSRSStage(in category: TKMSRSStage_Category) -> Int32 {
    switch category {
    case .burned: return 9
    case .enlightened: return 8
    case .master: return 7
    case .guru: return 5
    case .apprentice: return 1
    case .gpbUnrecognizedEnumeratorValue: fallthrough
    @unknown default: fatalError("Invalid category: \(category)")
    }
  }

  static func srsStageName(for srsStage: Int32) -> String {
    let category = srsStageCategory(for: srsStage)
    let name = srsStageCategoryName(for: category)

    let diff = srsStage - firstSRSStage(in: category)
    return "\(name) \(diff + 1)"
  }

  static func minGuruTime(_ itemLevel: Int32, srsStage: Int32) -> TimeInterval {
    let isAccelerated = itemLevel <= 2
    var seconds: Double = 0
    switch srsStage {
    case 1:
      seconds += 3600 * (isAccelerated ? 2 : 4)
      fallthrough
    case 2:
      seconds += 3600 * (isAccelerated ? 4 : 8)
      fallthrough
    case 3:
      seconds += 3600 * (isAccelerated ? 8 : 23)
      fallthrough
    case 4:
      seconds += 3600 * (isAccelerated ? 23 : 47)
    default: break
    }
    return seconds
  }
}

extension TKMSRSStage_Category {
  func name() -> String {
    switch self {
    case .burned: return "Burned"
    case .enlightened: return "Enlightened"
    case .master: return "Master"
    case .guru: return "Guru"
    case .apprentice: return "Apprentice"
    case .gpbUnrecognizedEnumeratorValue: fallthrough
    @unknown default: fatalError("Unrecognized category")
    }
  }
}

extension TKMSubject_Type {
  func name() -> String {
    switch self {
    case .empty: return "Random"
    case .radical: return "Radical"
    case .kanji: return "Kanji"
    case .vocabulary: return "Vocabulary"
    case .gpbUnrecognizedEnumeratorValue: fallthrough
    @unknown default: fatalError("Unrecognized type")
    }
  }
}

@objc extension TKMSubject {
  func japaneseText(imageSize _imageSize: Float) -> NSAttributedString {
    if !hasRadical || !radical.hasCharacterImageFile {
      return NSAttributedString(string: japanese)
    }
    let imageAttachment = NSTextAttachment()
    var imageSize = CGFloat(_imageSize)
    imageAttachment.image = UIImage(named: "radical-\(id_p)")
    if imageSize == 0 { imageSize = imageAttachment.image!.size.width }
    imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageSize, height: imageSize)
    return NSAttributedString(attachment: imageAttachment)
  }

  var japaneseText: NSAttributedString { japaneseText(imageSize: 0) }

  var subjectTypeString: String {
    if hasRadical { return "radical" }
    if hasKanji { return "kanji" }
    if hasVocabulary { return "vocabulary" }
    fatalError()
  }

  var subjectType: TKMSubject_Type {
    if hasRadical { return .radical }
    if hasKanji { return .kanji }
    if hasVocabulary { return .vocabulary }
    fatalError()
  }

  func primaryMeaning() -> String? {
    let meaningArray = meaningsArray as! [TKMMeaning]
    for meaning in meaningArray {
      if meaning.type == TKMMeaning_Type.primary { return meaning.meaning }
    }
    return nil
  }

  func readingsFilteredByPrimary(primary: Bool) -> [TKMReading] {
    var ret = [TKMReading]()
    let readingArray = readingsArray as! [TKMReading]
    for reading in readingArray {
      if reading.isPrimary == primary { ret.append(reading) }
    }
    return ret
  }

  var primaryReadings: [TKMReading] { readingsFilteredByPrimary(primary: true) }
  var alternateReadings: [TKMReading] { readingsFilteredByPrimary(primary: false) }

  func commaSeparatedMeanings() -> String {
    var strings = [String]()
    let meaningArray = meaningsArray as! [TKMMeaning]
    for meaning in meaningArray {
      if meaning.type != .blacklist || meaning.type != .auxiliaryWhitelist ||
        !hasRadical || Settings.showOldMnemonic {
        strings.append(meaning.meaning)
      }
    }
    return strings.joined(separator: ", ")
  }

  func commaSeparatedReadings() -> String {
    var strings = [String]()
    let readingArray = readingsArray as! [TKMReading]
    for reading in readingArray {
      strings.append(reading.reading)
    }
    return strings.joined(separator: ", ")
  }

  func commaSeparatedPrimaryReadings() -> String {
    var strings = [String]()
    for reading in primaryReadings {
      strings.append(reading.displayText)
    }
    return strings.joined(separator: ", ")
  }

  func randomAudioID() -> Int32 {
    if !hasVocabulary || vocabulary!.audioIdsArray.count < 1 { return 0 }
    return vocabulary!.audioIdsArray
      .value(at: UInt.random(in: 0 ..< vocabulary.audioIdsArray.count))
  }
}

@objc extension TKMReading {
  var displayText: String {
    if hasType, type == TKMReading_Type.onyomi, Settings.useKatakanaForOnyomi {
      return reading.applyingTransform(StringTransform.hiraganaToKatakana, reverse: false) ?? ""
    }
    return reading
  }
}

@objc extension TKMVocabulary {
  var commaSeparatedPartsOfSpeech: String {
    var parts = [String]()
    partsOfSpeechArray.enumerateValues { val, _, _ in
      var str = ""
      let value = TKMVocabulary_PartOfSpeech(rawValue: val)
      switch value {
      case .noun: str = "Noun"
      case .numeral: str = "Numeral"
      case .intransitiveVerb: str = "Intransitive Verb"
      case .ichidanVerb: str = "Ichidan Verb"
      case .transitiveVerb: str = "Transitive Verb"
      case .noAdjective: str = "No Adjective"
      case .godanVerb: str = "Godan Verb"
      case .naAdjective: str = "Na Adjective"
      case .iAdjective: str = "I Adjective"
      case .suffix: str = "Suffix"
      case .adverb: str = "Adverb"
      case .suruVerb: str = "Suru Verb"
      case .prefix: str = "Prefix"
      case .properNoun: str = "Proper Noun"
      case .expression: str = "Expression"
      case .adjective: str = "Adjective"
      case .interjection: str = "Interjection"
      case .counter: str = "Counter"
      case .pronoun: str = "Pronoun"
      case .conjunction: str = "Conjunction"
      default: break
      }
      parts.append(str)
    }
    return parts.joined(separator: ", ")
  }

  func isPartOfSpeech(part: TKMVocabulary_PartOfSpeech) -> Bool {
    for i in 0 ..< partsOfSpeechArray.count {
      if partsOfSpeechArray.value(at: i) == part.rawValue { return true }
    }
    return false
  }

  func isVerb() -> Bool {
    for i in 0 ..< partsOfSpeechArray.count {
      let partOfSpeech = TKMVocabulary_PartOfSpeech(rawValue: partsOfSpeechArray.value(at: i))
      switch partOfSpeech {
      case .godanVerb: fallthrough
      case .ichidanVerb: fallthrough
      case .suruVerb: fallthrough
      case .transitiveVerb: fallthrough
      case .intransitiveVerb: return true
      default: break
      }
    }
    return false
  }

  func isGodanVerb() -> Bool { isPartOfSpeech(part: TKMVocabulary_PartOfSpeech.godanVerb) }
  func isSuruVerb() -> Bool { isPartOfSpeech(part: TKMVocabulary_PartOfSpeech.suruVerb) }
  func isNoun() -> Bool { isPartOfSpeech(part: TKMVocabulary_PartOfSpeech.noun) }

  func isAdjective() -> Bool {
    for i in 0 ..< partsOfSpeechArray.count {
      let partOfSpeech = TKMVocabulary_PartOfSpeech(rawValue: partsOfSpeechArray.value(at: i))
      switch partOfSpeech {
      case .adjective: fallthrough
      case .naAdjective: fallthrough
      case .iAdjective: fallthrough
      case .noAdjective: return true
      default: break
      }
    }
    return false
  }

  func isPrefixOrSuffix() -> Bool {
    for i in 0 ..< partsOfSpeechArray.count {
      let partOfSpeech = TKMVocabulary_PartOfSpeech(rawValue: partsOfSpeechArray.value(at: i))
      switch partOfSpeech {
      case .prefix: fallthrough
      case .suffix: return true
      default: break
      }
    }
    return false
  }
}

@objc extension TKMAssignment {
  var isLessonStage: Bool { !isLocked && !hasStartedAt && srsStage == 0 }
  var isReviewStage: Bool { !isLocked && hasAvailableAt }
  var isBurned: Bool { srsStage == 9 }
  var isLocked: Bool { !hasSrsStage }
  var availableAtDate: Date { Date(timeIntervalSince1970: TimeInterval(availableAt)) }
  var startedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
  var passedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(passedAt)) }

  var reviewDate: Date? {
    if isBurned || isLocked { return nil }

    // If it's available now, treat it like it will be reviewed this hour.
    let calendar = Calendar.current
    let components = calendar.dateComponents([Calendar.Component.year, .month, .day, .hour],
                                             from: Date())
    var reviewDate = calendar.date(from: components)
    if !hasAvailableAt { return reviewDate }

    // If it's not available now, treat it like it will be reviewed within the hour it comes
    // available.
    if reviewDate! < availableAtDate { reviewDate = availableAtDate }
    return reviewDate
  }

  func guruDate(for subject: TKMSubject) -> Date? {
    if hasPassedAt, srsStage >= 5 { return passedAtDate }
    else if srsStage >= 5 { return Date.distantPast }

    let reviewDate = self.reviewDate ?? Date()
    let guruSeconds = Convenience.minGuruTime(subject.level, srsStage: srsStage + 1)
    return reviewDate + guruSeconds
  }
}

@objc extension TKMProgress {
  func reviewFormParameters() -> String {
    """
    \(assignment.subjectId)%%5B%%5D=\(hasMeaningWrong ? (meaningWrong ? "1" : "0") : "")\
    &\(assignment.subjectId)%%5B%%5D=\(hasReadingWrong ? (readingWrong ? "1" : "0") : "")"
    """
  }

  func lessonFormParameters() -> String { "keys%%5B%%5D=\(assignment.subjectId)" }
  func createdAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }
}

@objc extension TKMUser {
  func startedAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
  func currentLevel() -> Int32 { min(level, maxLevelGrantedBySubscription) }
}

@objc extension TKMLevel {
  func unlockedAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(unlockedAt)) }
  func startedAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
  func passedAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(passedAt)) }
  func abandonedAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(abandonedAt)) }
  func completedAtDate() -> Date { Date(timeIntervalSince1970: TimeInterval(completedAt)) }
  func timeSpentCurrent() -> TimeInterval {
    if !hasUnlockedAt { return 0 }
    let startDate = hasStartedAt ? startedAtDate() : unlockedAtDate()
    if hasPassedAt { return passedAtDate().timeIntervalSince(startDate) }
    else { return Date().timeIntervalSince(startDate) }
  }
}
