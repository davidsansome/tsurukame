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

@objc enum ReviewOrder: UInt, Codable, CustomStringConvertible {
  case random = 1
  case ascendingSRSStage = 2
  case currentLevelFirst = 3
  case lowestLevelFirst = 4
  case newestAvailableFirst = 5
  case oldestAvailableFirst = 6
  case descendingSRSStage = 7

  var description: String {
    switch self {
    case .random: return "Random"
    case .ascendingSRSStage: return "Ascending SRS stage"
    case .descendingSRSStage: return "Descending SRS stage"
    case .currentLevelFirst: return "Current level first"
    case .lowestLevelFirst: return "Lowest level first"
    case .newestAvailableFirst: return "Newest available first"
    case .oldestAvailableFirst: return "Oldest available first"
    }
  }
}

@objc enum InterfaceStyle: UInt, Codable, CustomStringConvertible {
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
    let archiver = NSKeyedArchiver()
    archiver.requiresSecureCoding = true
    archiver.encode(object, forKey: key)
    data = archiver.encodedData
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

@propertyWrapper struct Setting<T: Codable> {
  private let defaultValue: T
  private let key: String

  init(_ defaultValue: T, _ key: String) {
    self.defaultValue = defaultValue
    self.key = key
  }

  var wrappedValue: T {
    get { getArchiveData(defaultValue, key: key) }
    set(newValue) { setArchiveData(newValue, key: key) }
  }
}

@propertyWrapper struct EnumSetting<T: RawRepresentable> where T.RawValue: Codable {
  private let defaultValue: T
  private let key: String

  init(_ defaultValue: T, _ key: String) {
    self.defaultValue = defaultValue
    self.key = key
  }

  var wrappedValue: T {
    get { T(rawValue: getArchiveData(defaultValue.rawValue, key: key))! }
    set(newValue) { setArchiveData(newValue.rawValue, key: key) }
  }
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

  @Setting(false, #keyPath(prioritizeCurrentLevel)) static var prioritizeCurrentLevel: Bool
  @EnumArraySetting([
    .radical,
    .kanji,
    .vocabulary,
  ], "lessonOrder") static var lessonOrder: [TKMSubject.TypeEnum]
  @Setting(5, #keyPath(lessonBatchSize)) static var lessonBatchSize: Int

  @EnumSetting(ReviewOrder.random, #keyPath(reviewOrder)) static var reviewOrder: ReviewOrder
  @Setting(5, #keyPath(reviewBatchSize)) static var reviewBatchSize: Int
  @Setting(false, #keyPath(groupMeaningReading)) static var groupMeaningReading: Bool
  @Setting(true, #keyPath(meaningFirst)) static var meaningFirst: Bool
  @Setting(true, #keyPath(showAnswerImmediately)) static var showAnswerImmediately: Bool
  @Setting([], #keyPath(selectedFonts)) static var selectedFonts: Set<String>
  @Setting(1.0, #keyPath(fontSize)) static var fontSize: Float
  @Setting(false, #keyPath(exactMatch)) static var exactMatch: Bool
  @Setting(true, #keyPath(enableCheats)) static var enableCheats: Bool
  @Setting(true, #keyPath(showOldMnemonic)) static var showOldMnemonic: Bool
  @Setting(true, #keyPath(useKatakanaForOnyomi)) static var useKatakanaForOnyomi: Bool
  @Setting(false, #keyPath(showSRSLevelIndicator)) static var showSRSLevelIndicator: Bool
  @Setting(false, #keyPath(showAllReadings)) static var showAllReadings: Bool
  @Setting(false, #keyPath(autoSwitchKeyboard)) static var autoSwitchKeyboard: Bool
  @Setting(false, #keyPath(allowSkippingReviews)) static var allowSkippingReviews: Bool
  @Setting(true, #keyPath(minimizeReviewPenalty)) static var minimizeReviewPenalty: Bool

  @Setting(false, #keyPath(playAudioAutomatically)) static var playAudioAutomatically: Bool
  @Setting([], #keyPath(installedAudioPackages)) static var installedAudioPackages: Set<String>

  @Setting(true, #keyPath(animateParticleExplosion)) static var animateParticleExplosion: Bool
  @Setting(true, #keyPath(animateLevelUpPopup)) static var animateLevelUpPopup: Bool
  @Setting(true, #keyPath(animatePlusOne)) static var animatePlusOne: Bool

  @Setting(true,
           #keyPath(subjectCatalogueViewShowAnswers)) static var subjectCatalogueViewShowAnswers: Bool
}
