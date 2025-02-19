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
    let data = keyValueStore?.data(forKey: getCloudStorageKey())
    if data != nil {
      do {
        let decoded = try JSONSerialization.jsonObject(with: data!)
        if let mistakes = decoded as? [String: String] {
          // re-create dict to be [Int32: Date] from [String: String]
          var outputDict = [Int32: Date]()
          mistakes.forEach { el in
            outputDict[Int32(el.key)!] = dateFormatter.date(from: el.value)
          }
          return outputDict
        }
      } catch {
        NSLog("Unable to deserialize mistakes from JSON")
      }
    }
    return [:]
  }

  func uploadMistakesToCloud(mistakes: [Int32: Date]) {
    // write back to cloud
    do {
      // All JSON keys must be strings. So, we have to remake the dictionary to encode keys and
      // values to strings. (The JSON encoder did not play nice with native Date objects, either.)
      var strKeyDict = [String: String]()
      mistakes.forEach { el in
        strKeyDict[String(el.key)] = dateFormatter.string(from: el.value)
      }
      let json = try JSONSerialization.data(withJSONObject: strKeyDict)
      keyValueStore?.set(json, forKey: getCloudStorageKey())
      // sync latest date as well so that other devices are sure to get an update
      keyValueStore?.set(Date(), forKey: "lastSyncCall")
      keyValueStore?.synchronize() // fails silently if no iCloud account
    } catch {
      NSLog("Unable to serialize mistakes to JSON")
    }
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
