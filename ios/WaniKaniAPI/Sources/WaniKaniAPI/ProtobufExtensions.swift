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
import UIKit

@objc(TKMProtobufExtensions)
@objcMembers
public class ProtobufExtensionsObjectiveC: NSObject {
  public static func srsStageCategoryName(_ value: Int) -> String {
    SRSStageCategory(rawValue: value)!.description
  }

  public static func srsStageName(_ value: Int) -> String {
    SRSStage(rawValue: value)!.description
  }

  public static func subjectTypeName(_ value: Int) -> String {
    TKMSubject.TypeEnum(rawValue: value)!.description
  }
}

@objc(TKMSRSStageCategory)
public enum SRSStageCategory: Int, CustomStringConvertible, Comparable, Strideable {
  case apprentice = 0
  case guru = 1
  case master = 2
  case enlightened = 3
  case burned = 4

  public static func < (lhs: SRSStageCategory, rhs: SRSStageCategory) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public func distance(to other: SRSStageCategory) -> SRSStageCategory.Stride {
    Stride(other.rawValue) - Stride(rawValue)
  }

  public func advanced(by n: SRSStageCategory.Stride) -> SRSStageCategory {
    SRSStageCategory(rawValue: Int(Stride(rawValue) + n))!
  }

  public typealias Stride = Int

  public var description: String {
    switch self {
    case .apprentice: return "Apprentice"
    case .guru: return "Guru"
    case .master: return "Master"
    case .enlightened: return "Enlightened"
    case .burned: return "Burned"
    }
  }

  public var firstSrsStage: SRSStage {
    switch self {
    case .apprentice: return .apprentice1
    case .guru: return .guru1
    case .master: return .master
    case .enlightened: return .enlightened
    case .burned: return .burned
    }
  }
}

@objc(TKMSRSStage)
public enum SRSStage: Int, CustomStringConvertible, Comparable, Strideable {
  case unlocking = 0
  case apprentice1 = 1
  case apprentice2 = 2
  case apprentice3 = 3
  case apprentice4 = 4
  case guru1 = 5
  case guru2 = 6
  case master = 7
  case enlightened = 8
  case burned = 9

  public static func < (lhs: SRSStage, rhs: SRSStage) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public func distance(to other: SRSStage) -> SRSStage.Stride {
    Stride(other.rawValue) - Stride(rawValue)
  }

  public func advanced(by n: SRSStage.Stride) -> SRSStage {
    let value = min(SRSStage.burned.rawValue,
                    max(SRSStage.apprentice1.rawValue, Int(Stride(rawValue) + n)))
    return SRSStage(rawValue: value)!
  }

  public typealias Stride = Int

  public var next: SRSStage { advanced(by: 1) }
  public var previous: SRSStage { advanced(by: -1) }

  public var description: String {
    switch self {
    case .unlocking: return "Lesson"
    case .apprentice1: return "Apprentice I"
    case .apprentice2: return "Apprentice II"
    case .apprentice3: return "Apprentice III"
    case .apprentice4: return "Apprentice IV"
    case .guru1: return "Guru I"
    case .guru2: return "Guru II"
    case .master: return "Master"
    case .enlightened: return "Enlightened"
    case .burned: return "Burned"
    }
  }

  public var category: SRSStageCategory {
    switch self {
    case .apprentice1, .apprentice2, .apprentice3, .apprentice4, .unlocking: return .apprentice
    case .guru1, .guru2: return .guru
    case .master: return .master
    case .enlightened: return .enlightened
    case .burned: return .burned
    }
  }

  public func minimumTimeUntilGuru(itemLevel: Int) -> TimeInterval {
    let isAccelerated = itemLevel <= 2

    var hours = 0
    // From https://docs.api.wanikani.com/20170710/#additional-information
    switch self {
    case .apprentice1:
      hours += (isAccelerated ? 2 : 4)
      fallthrough
    case .apprentice2:
      hours += (isAccelerated ? 4 : 8)
      fallthrough
    case .apprentice3:
      hours += (isAccelerated ? 8 : 23)
      fallthrough
    case .apprentice4:
      hours += (isAccelerated ? 23 : 47)
    default:
      break
    }
    return TimeInterval(hours * 60 * 60)
  }
}

extension TKMSubject.TypeEnum: Codable, CustomStringConvertible {
  public var description: String {
    switch self {
    case .radical: return "Radical"
    case .kanji: return "Kanji"
    case .vocabulary: return "Vocabulary"
    default: return "Random"
    }
  }
}

public extension TKMSubject {
  var subjectType: TKMSubject.TypeEnum {
    if hasRadical {
      return .radical
    }
    if hasKanji {
      return .kanji
    }
    if hasVocabulary {
      return .vocabulary
    }
    return .unknown
  }

  public func japaneseText(imageSize: CGFloat) -> NSAttributedString {
    if !hasRadical || !radical.hasCharacterImageFile_p {
      return NSAttributedString(string: japanese)
    }

    let imageAttachment = NSTextAttachment()
    imageAttachment.image = UIImage(named: "radical-\(id)")

    var size = imageSize
    if size == 0 {
      size = imageAttachment.image!.size.width
    }
    imageAttachment.bounds = CGRect(x: 0, y: 0, width: size, height: size)
    return NSAttributedString(attachment: imageAttachment)
  }

  public var japaneseText: NSAttributedString { japaneseText(imageSize: 0) }

  public var primaryMeaning: String {
    for meaning in meanings {
      if meaning.type == .primary {
        return meaning.meaning
      }
    }
    return ""
  }

  private func readings(primary: Bool) -> [TKMReading] {
    var ret = [TKMReading]()
    for reading in readings {
      if reading.isPrimary == primary {
        ret.append(reading)
      }
    }
    return ret
  }

  public var primaryReadings: [TKMReading] { readings(primary: true) }
  public var alternateReadings: [TKMReading] { readings(primary: false) }

  public func commaSeparatedMeanings(showOldMnemonic: Bool) -> String {
    var strings = [String]()
    for meaning in meanings {
      if meaning.type != .blacklist,
        meaning.type != .auxiliaryWhitelist || !hasRadical || showOldMnemonic {
        strings.append(meaning.meaning)
      }
    }
    return strings.joined(separator: ", ")
  }

  private func commaSeparated(readings: [TKMReading]) -> String {
    var strings = [String]()
    for reading in readings {
      strings.append(reading.reading)
    }
    return strings.joined(separator: ", ")
  }

  public var commaSeparatedReadings: String { commaSeparated(readings: readings) }
  public var commaSeparatedPrimaryReadings: String { commaSeparated(readings: primaryReadings) }

  public func randomAudioID() -> Int {
    if !hasVocabulary || vocabulary.audioIds.count < 1 {
      return 0
    }
    let idx = arc4random_uniform(UInt32(vocabulary.audioIds.count))
    return Int(vocabulary.audioIds[Int(idx)])
  }
}

public extension TKMReading {
  public func displayText(useKatakanaForOnyomi: Bool) -> String {
    if hasType, type == .onyomi, useKatakanaForOnyomi {
      return reading.applyingTransform(.hiraganaToKatakana, reverse: false)!
    }
    return reading
  }
}

extension TKMVocabulary.PartOfSpeech: CustomStringConvertible {
  public var description: String {
    switch self {
    case .noun:
      return "Noun"
    case .numeral:
      return "Numeral"
    case .intransitiveVerb:
      return "Intransitive Verb"
    case .ichidanVerb:
      return "Ichidan Verb"
    case .transitiveVerb:
      return "Transitive Verb"
    case .noAdjective:
      return "No Adjective"
    case .godanVerb:
      return "Godan Verb"
    case .naAdjective:
      return "Na Adjective"
    case .iAdjective:
      return "I Adjective"
    case .suffix:
      return "Suffix"
    case .adverb:
      return "Adverb"
    case .suruVerb:
      return "Suru Verb"
    case .prefix:
      return "Prefix"
    case .properNoun:
      return "Proper Noun"
    case .expression:
      return "Expression"
    case .adjective:
      return "Adjective"
    case .interjection:
      return "Interjection"
    case .counter:
      return "Counter"
    case .pronoun:
      return "Pronoun"
    case .conjunction:
      return "Conjunction"
    default:
      return ""
    }
  }
}

public extension TKMVocabulary {
  public var commaSeparatedPartsOfSpeech: String {
    var strings = [String]()
    for partOfSpeech in partsOfSpeech {
      strings.append(partOfSpeech.description)
    }
    return strings.joined(separator: ", ")
  }

  private func isA(partOfSpeech: TKMVocabulary.PartOfSpeech) -> Bool {
    partsOfSpeech.contains(partOfSpeech)
  }

  public var isGodanVerb: Bool { isA(partOfSpeech: .godanVerb) }
  public var isSuruVerb: Bool { isA(partOfSpeech: .suruVerb) }
  public var isNoun: Bool { isA(partOfSpeech: .noun) }
  public var isVerb: Bool {
    isA(partOfSpeech: .godanVerb) ||
      isA(partOfSpeech: .ichidanVerb) ||
      isA(partOfSpeech: .suruVerb) ||
      isA(partOfSpeech: .transitiveVerb) ||
      isA(partOfSpeech: .intransitiveVerb)
  }

  public var isAdjective: Bool {
    isA(partOfSpeech: .adjective) ||
      isA(partOfSpeech: .iAdjective) ||
      isA(partOfSpeech: .naAdjective) ||
      isA(partOfSpeech: .noAdjective)
  }

  public var isPrefixOrSuffix: Bool { isA(partOfSpeech: .prefix) || isA(partOfSpeech: .suffix) }
}

private let kGuruStage = 5

public extension TKMAssignment {
  public var srsStage: SRSStage { SRSStage(rawValue: Int(srsStageNumber))! }

  public var isLessonStage: Bool { !isLocked && !hasStartedAt && srsStage == .unlocking }
  public var isReviewStage: Bool { !isLocked && hasAvailableAt }
  public var isBurned: Bool { srsStage == .burned }
  public var isLocked: Bool { !hasSrsStageNumber }
  public var availableAtDate: Date { Date(timeIntervalSince1970: TimeInterval(availableAt)) }
  public var startedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
  public var passedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(passedAt)) }

  public var reviewDate: Date? {
    if isBurned || isLocked {
      return nil
    }

    // If it's available now, treat it like it will be reviewed this hour.
    let calendar = NSCalendar.current
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
    let reviewDate = calendar.date(from: components)

    if !hasAvailableAt {
      return reviewDate
    }

    // If it's not available now, treat it like it will be reviewed within the hour it comes
    // available.
    if let comparison = reviewDate?.compare(availableAtDate), comparison == .orderedAscending {
      return availableAtDate
    }
    return reviewDate
  }

  public func guruDate(subject: TKMSubject) -> Date? {
    if hasPassedAt, srsStage > .guru1 {
      return passedAtDate
    } else if srsStage >= .guru1 {
      return Date.distantPast
    }

    let guruSeconds = srsStage.next.minimumTimeUntilGuru(itemLevel: Int(subject.level))
    return reviewDate?.addingTimeInterval(guruSeconds)
  }
}

public extension TKMProgress {
  public var createdAtDate: Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }
}

public extension TKMUser {
  public var startedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
  public var currentLevel: Int32 { min(level, maxLevelGrantedBySubscription) }
}

public extension TKMLevel {
  public var unlockedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(unlockedAt)) }
  public var startedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(startedAt)) }
  public var passedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(passedAt)) }
  public var abandonedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(abandonedAt)) }
  public var completedAtDate: Date { Date(timeIntervalSince1970: TimeInterval(completedAt)) }
  public var createdAtDate: Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }

  public var timeSpentCurrent: TimeInterval {
    if !hasUnlockedAt {
      return 0
    }
    let startDate = hasStartedAt ? startedAtDate : unlockedAtDate
    if hasPassedAt {
      return passedAtDate.timeIntervalSince(startDate)
    }
    return Date().timeIntervalSince(startDate)
  }
}
