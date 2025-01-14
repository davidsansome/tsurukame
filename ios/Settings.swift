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

typealias SettingEnum = CaseIterable & Codable & CustomStringConvertible & RawRepresentable

@objc enum ReviewOrder: UInt, SettingEnum {
  case random = 1
  case ascendingSRSStage = 2
  case currentLevelFirst = 3
  case lowestLevelFirst = 4
  case newestAvailableFirst = 5
  case oldestAvailableFirst = 6
  case descendingSRSStage = 7
  case longestRelativeWait = 8

  var description: String {
    switch self {
    case .random: return "Random"
    case .ascendingSRSStage: return "Ascending SRS stage"
    case .descendingSRSStage: return "Descending SRS stage"
    case .currentLevelFirst: return "Current level first"
    case .lowestLevelFirst: return "Lowest level first"
    case .newestAvailableFirst: return "Newest available first"
    case .oldestAvailableFirst: return "Oldest available first"
    case .longestRelativeWait: return "Longest relative wait"
    }
  }
}

@objc enum InterfaceStyle: UInt, SettingEnum {
  case system = 1
  case light = 2
  case dark = 3

  var description: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}

private func setArchiveData<T: Codable>(_ object: T, key: String) {
  var data: Data!
  if #available(iOS 11.0, *) {
    data = try! NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true)
  } else {
    data = NSKeyedArchiver.archivedData(withRootObject: object)
  }

  UserDefaults.standard.setValue(data, forKey: key)
}

private func getArchiveData<T: Codable>(_ defaultValue: T, key: String) -> T {
  // Encode anything not encoded
  if let notEncodedObject = UserDefaults.standard.object(forKey: key) as? T {
    setArchiveData(notEncodedObject, key: key)
  }
  // Decode value if obtainable and return it
  guard let data = UserDefaults.standard.object(forKey: key) as? Data else {
    setArchiveData(defaultValue, key: key)
    return defaultValue
  }
  return (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T) ?? defaultValue
}

protocol SettingProtocol {
  associatedtype ValueType

  var defaultValue: ValueType { get }
  var wrappedValue: ValueType { get set }
}

@propertyWrapper struct Setting<T: Codable>: SettingProtocol {
  let defaultValue: T
  let key: String

  init(_ defaultValue: T, _ key: String) {
    self.defaultValue = defaultValue
    self.key = key
  }

  var wrappedValue: T {
    get { getArchiveData(defaultValue, key: key) }
    set(newValue) { setArchiveData(newValue, key: key) }
  }

  var projectedValue: Setting<T> { self }
}

@propertyWrapper struct EnumSetting<T: RawRepresentable>: SettingProtocol
  where T.RawValue: Codable {
  typealias ValueType = T

  let defaultValue: T
  let key: String

  init(_ defaultValue: T, _ key: String) {
    self.defaultValue = defaultValue
    self.key = key
  }

  var wrappedValue: T {
    get { T(rawValue: getArchiveData(defaultValue.rawValue, key: key))! }
    set(newValue) { setArchiveData(newValue.rawValue, key: key) }
  }

  var projectedValue: EnumSetting<T> { self }
}

@propertyWrapper struct EnumArraySetting<A: Sequence, T: RawRepresentable> where A.Element == T,
  T.RawValue: Codable {
  private let defaultValue: [T.RawValue]
  private let key: String

  init(_ defaultValues: A, _ key: String) {
    defaultValue = EnumArraySetting<A, T>.toRawArray(defaultValues)
    self.key = key
  }

  private static func toRawArray(_ values: A) -> [T.RawValue] {
    var ret = [T.RawValue]()
    for value in values {
      ret.append(value.rawValue)
    }
    return ret
  }

  private static func fromRawArray(_ values: [T.RawValue]) -> A {
    var ret = [T]()
    for value in values {
      ret.append(T(rawValue: value)!)
    }
    return ret as! A
  }

  var wrappedValue: A {
    get { EnumArraySetting<A, T>.fromRawArray(getArchiveData(defaultValue, key: key)) }
    set(newValue) { setArchiveData(EnumArraySetting<A, T>.toRawArray(newValue), key: key) }
  }
}

@objcMembers class Settings: NSObject {
  @Setting("", #keyPath(userCookie)) static var userCookie: String
  @Setting("", #keyPath(userEmailAddress)) static var userEmailAddress: String
  @Setting("", #keyPath(userApiToken)) static var userApiToken: String

  @EnumSetting(InterfaceStyle.system,
               #keyPath(interfaceStyle)) static var interfaceStyle: InterfaceStyle

  @Setting(false, #keyPath(notificationsAllReviews)) static var notificationsAllReviews: Bool
  @Setting(true, #keyPath(notificationsBadging)) static var notificationsBadging: Bool
  @Setting(false, #keyPath(notificationSounds)) static var notificationSounds: Bool

  @Setting(false, #keyPath(prioritizeCurrentLevel)) static var prioritizeCurrentLevel: Bool
  @EnumArraySetting([
    .radical,
    .kanji,
    .vocabulary,
  ], "lessonOrder") static var lessonOrder: [TKMSubject.TypeEnum]
  @Setting(5, #keyPath(lessonBatchSize)) static var lessonBatchSize: Int
  @Setting(true, #keyPath(showStatsSection)) static var showStatsSection: Bool
  @Setting(false, #keyPath(showArtwork)) static var showArtwork: Bool

  @EnumSetting(ReviewOrder.random, #keyPath(reviewOrder)) static var reviewOrder: ReviewOrder
  @Setting(5, #keyPath(reviewBatchSize)) static var reviewBatchSize: Int
  @Setting(15, #keyPath(reviewItemsLimit)) static var reviewItemsLimit: Int
  @Setting(Int.max, #keyPath(apprenticeLessonsLimit)) static var apprenticeLessonsLimit: Int
  @Setting(false, #keyPath(groupMeaningReading)) static var groupMeaningReading: Bool
  @Setting(false, #keyPath(reviewItemsLimitEnabled)) static var reviewItemsLimitEnabled: Bool
  @Setting(true, #keyPath(meaningFirst)) static var meaningFirst: Bool
  @Setting(true, #keyPath(showAnswerImmediately)) static var showAnswerImmediately: Bool
  @Setting(false, #keyPath(showFullAnswer)) static var showFullAnswer: Bool
  @Setting([], #keyPath(selectedFonts)) static var selectedFonts: Set<String>
  @Setting(1.0, #keyPath(fontSize)) static var fontSize: Float
  @Setting(false, #keyPath(exactMatch)) static var exactMatch: Bool
  @Setting(true, #keyPath(enableCheats)) static var enableCheats: Bool
  @Setting(true, #keyPath(showOldMnemonic)) static var showOldMnemonic: Bool
  @Setting(false, #keyPath(useKatakanaForOnyomi)) static var useKatakanaForOnyomi: Bool
  @Setting(false, #keyPath(showSRSLevelIndicator)) static var showSRSLevelIndicator: Bool
  @Setting(false,
           #keyPath(showMinutesForNextLevelUpReview)) static var showMinutesForNextLevelUpReview: Bool
  @Setting(false, #keyPath(showAllReadings)) static var showAllReadings: Bool
  @Setting(false, #keyPath(autoSwitchKeyboard)) static var autoSwitchKeyboard: Bool
  @Setting(false, #keyPath(allowSkippingReviews)) static var allowSkippingReviews: Bool
  @Setting(true, #keyPath(minimizeReviewPenalty)) static var minimizeReviewPenalty: Bool
  @Setting(false, #keyPath(ankiMode)) static var ankiMode: Bool
  @Setting(false,
           #keyPath(ankiModeCombineReadingMeaning)) static var ankiModeCombineReadingMeaning: Bool
  @Setting(true, #keyPath(showPreviousLevelGraph)) static var showPreviousLevelGraph: Bool
  @Setting(true, #keyPath(showKanaOnlyVocab)) static var showKanaOnlyVocab: Bool

  @Setting(false, #keyPath(seenFullAnswerPrompt)) static var seenFullAnswerPrompt: Bool

  @Setting(false, #keyPath(playAudioAutomatically)) static var playAudioAutomatically: Bool
  @Setting(false, #keyPath(interruptBackgroundAudio)) static var interruptBackgroundAudio: Bool
  @Setting(false, #keyPath(offlineAudio)) static var offlineAudio: Bool
  @Setting(false, #keyPath(offlineAudioCellular)) static var offlineAudioCellular: Bool
  @Setting([], #keyPath(offlineAudioVoiceActors)) static var offlineAudioVoiceActors: Set<Int64>

  @Setting("", #keyPath(gravatarCustomEmail)) static var gravatarCustomEmail: String

  // Deprecated - remove after 1.24.
  @Setting([], #keyPath(installedAudioPackages)) static var installedAudioPackages: Set<String>

  @Setting(true, #keyPath(animateParticleExplosion)) static var animateParticleExplosion: Bool
  @Setting(true, #keyPath(animateLevelUpPopup)) static var animateLevelUpPopup: Bool
  @Setting(true, #keyPath(animatePlusOne)) static var animatePlusOne: Bool

  @Setting(true,
           #keyPath(subjectCatalogueViewShowAnswers)) static var subjectCatalogueViewShowAnswers: Bool
}
