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

class RecentMistakeHandler {
  var keyValueStore: NSUbiquitousKeyValueStore
  var fileNamePrefix: String
  private var dateFormatter: DateFormatter

  init(keyValueStore: NSUbiquitousKeyValueStore, storageFileNamePrefix: String?) {
    self.keyValueStore = keyValueStore
    fileNamePrefix = storageFileNamePrefix ?? ""
    dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  }

  func getCloudStorageKey() -> String {
    fileNamePrefix + "tsurukame-mistakes"
  }

  func getMistakesFromCloud() -> [Int32: Date] {
    let data = keyValueStore.dictionary(forKey: getCloudStorageKey()) as? [Int32: Date]
    return data ?? [:]
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

  func uploadRecentMistakesToCloud(mistakes: [Int32: Date]) {
    // write back to cloud
    // TODO: experiment writing to json string
    keyValueStore.set(mistakes, forKey: getCloudStorageKey())
    // make sure we get a notif on other devices
    keyValueStore.set(Date(), forKey: "lastSyncCall")
    keyValueStore.synchronize() // fails silently if no account
//        postNotificationOnMainQueue(.lccRecentMistakesCountChanged) // TODO: handle this
  }
}
