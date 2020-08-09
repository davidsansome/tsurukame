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

@objc enum ReviewOrder: UInt, Codable {
  case random = 1
  case ascendingSRSStage = 2
  case currentLevelFirst = 3
  case lowestLevelFirst = 4
  case newestAvailableFirst = 5
  case oldestAvailableFirst = 6
  case descendingSRSStage = 7
}

@objc enum InterfaceStyle: UInt, Codable {
  case system = 1
  case light = 2
  case dark = 3
}

@propertyWrapper struct Setting<T: Codable> {
  private let defaultValue: T
  private let key: String

  init(_ defaultValue: T, _ key: String) {
    self.defaultValue = defaultValue
    self.key = key
  }

  func archiveData(_ object: T) -> Data {
    if #available(iOS 11.0, *) {
      return try! NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true)
    } else {
      let archiver = NSKeyedArchiver()
      archiver.requiresSecureCoding = true
      archiver.encode(object, forKey: key)
      return archiver.encodedData
    }
  }

  var wrappedValue: T {
    get {
      if let notEncodedObject = UserDefaults.standard.object(forKey: key) as? T {
        return notEncodedObject
      }
      guard let data = UserDefaults.standard.object(forKey: key) as? Data
      else { return defaultValue }
      return (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T) ?? defaultValue
    }
    set(newValue) { UserDefaults.standard.set(archiveData(newValue), forKey: key) }
  }
}

@objcMembers class Settings: NSObject {
  @Setting("", #keyPath(userCookie)) static var userCookie: String
  @Setting("", #keyPath(userEmailAddress)) static var userEmailAddress: String
  @Setting("", #keyPath(userApiToken)) static var userApiToken: String

  @Setting(.system, #keyPath(interfaceStyle)) static var interfaceStyle: InterfaceStyle

  @Setting(false, #keyPath(notificationsAllReviews)) static var notificationsAllReviews: Bool
  @Setting(true, #keyPath(notificationsBadging)) static var notificationsBadging: Bool

  @Setting(false, #keyPath(prioritizeCurrentLevel)) static var prioritizeCurrentLevel: Bool
  @Setting([
    TKMSubject_Type.radical.rawValue,
    TKMSubject_Type.kanji.rawValue,
    TKMSubject_Type.vocabulary.rawValue,
  ], #keyPath(lessonOrder)) static var lessonOrder: [Int32]
  @Setting(5, #keyPath(lessonBatchSize)) static var lessonBatchSize: Int

  @Setting(.random, #keyPath(reviewOrder)) static var reviewOrder: ReviewOrder
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

  @Setting(false, #keyPath(playAudioAutomatically)) static var playAudioAutomatically: Bool
  @Setting([], #keyPath(installedAudioPackages)) static var installedAudioPackages: Set<String>

  @Setting(true, #keyPath(animateParticleExplosion)) static var animateParticleExplosion: Bool
  @Setting(true, #keyPath(animateLevelUpPopup)) static var animateLevelUpPopup: Bool
  @Setting(true, #keyPath(animatePlusOne)) static var animatePlusOne: Bool

  @Setting(true,
           #keyPath(subjectCatalogueViewShowAnswers)) static var subjectCatalogueViewShowAnswers: Bool
}
