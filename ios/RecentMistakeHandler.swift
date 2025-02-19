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

// struct RecentMistake {
//    var subjectId: Int32
//    var date: Date
//    init(subjectId: Int32, date: Date) {
//        self.subjectId = subjectId
//        self.date = date
//    }
// }

extension Notification.Name {
  static let rmhCloudUpdateReceived = Notification.Name(rawValue: "rmhCloudUpdateReceived")
}

class RecentMistakeHandler {
  var keyValueStore: NSUbiquitousKeyValueStore?
  var fileNamePrefix: String?
  private var dateFormatter: DateFormatter
  private var busySyncing = false
  private var gotRecentMistakesCloudNotificationWhileSyncing = false

  init() {
    dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  }

  func setup(keyStore: NSUbiquitousKeyValueStore, storageFileNamePrefix: String?) {
    keyValueStore = keyStore
    fileNamePrefix = storageFileNamePrefix
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(receivedCloudUpdate),
                                           name: NSUbiquitousKeyValueStore
                                             .didChangeExternallyNotification,
                                           object: keyValueStore)
    keyStore.synchronize()
  }

  func getCloudStorageKey() -> String {
    (fileNamePrefix ?? "") + "tsurukame-mistakes"
  }

  func getCloudMistakes() -> [Int32: Date] {
    let data = keyValueStore?.dictionary(forKey: getCloudStorageKey()) as? [Int32: Date]
    return data ?? [:]
  }

  func mergeMistakesWithCloud(mistakes: [Int32: Date]) -> [Int32: Date] {
    let cloudMistakes = getCloudMistakes()
    // merge existing mistakes from storage and cloud
    return RecentMistakeHandler.mergeMistakes(original: mistakes, other: cloudMistakes)
  }

  func uploadRecentMistakesToCloud(mistakes: [Int32: Date]) {
    // write back to cloud
    // note: should we write JSON here instead?
    keyValueStore?.set(mistakes, forKey: getCloudStorageKey())
    // sync latest date as well so that other devices are sure to get an update
    keyValueStore?.set(Date(), forKey: "lastSyncCall")
    keyValueStore?.synchronize() // fails silently if no iCloud account
  }

  // Merge 2 dictionaries together and clean up any unnecessary data in the array along the way
  static func mergeMistakes(original: [Int32: Date], other: [Int32: Date]) -> [Int32: Date] {
    var output = [Int32: Date]()
    let dayAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
    [original, other].forEach { dict in
      dict.forEach { mistake in
        let subjectID = mistake.key
        let dateToAdd = mistake.value
        if dateToAdd >= dayAgo {
          if let currentMistakeDate = output[subjectID] {
            // compare the existing item in the output with the "new" item from this dictionary.
            // We want the newer date of the two dates because we want the user to have the
            // max 24 hrs for the recent mistake available.
            output[subjectID] = dateToAdd > currentMistakeDate ? dateToAdd :
              currentMistakeDate
          } else {
            // we don't have data on this subjectID yet, so go ahead and add it in
            output[subjectID] = dateToAdd
          }
        }
      }
    }
    return output
  }

  @objc func receivedCloudUpdate(notification _: NSNotification) {
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .rmhCloudUpdateReceived,
                                      object: self.getCloudMistakes())
    }
  }
}
