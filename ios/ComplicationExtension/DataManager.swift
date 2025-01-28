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
import os

typealias UserData = [String: Any]

protocol DataManagerDelegate: AnyObject {
  func onDataUpdated(data: UserData, dataSource: ComplicationDataSource)
}

enum ComplicationDataSource: Int {
  case ReviewCounts, Level, Character
}

class DataManager {
  private let userDefaultsKeyData = "LastKnownData"
  private let userDefaultsKeySource = "DataSource"
  private let dataStaleLimit = TimeInterval(60 * 60 * 2)

  public static let sharedInstance = DataManager()
  var latestData: UserData?
  var delegates: [DataManagerDelegate] = []
  public var dataSource: ComplicationDataSource = .ReviewCounts {
    didSet {
      UserDefaults.standard.set(dataSource.rawValue, forKey: userDefaultsKeySource)
    }
  }

  private init() {
    // Load the last known data from last time
    latestData = UserDefaults.standard.dictionary(forKey: userDefaultsKeyData)
    dataSource = ComplicationDataSource(rawValue: UserDefaults.standard
      .integer(forKey: userDefaultsKeySource)) ?? .ReviewCounts

    WatchHelper.sharedInstance.awaitMessages { userInfo in
      if self.isDataOutOfDate(userData: userInfo) {
        return
      }

      self.latestData = userInfo

      UserDefaults.standard.set(userInfo, forKey: self.userDefaultsKeyData)

      for delegate in self.delegates {
        delegate.onDataUpdated(data: userInfo, dataSource: self.dataSource)
      }
    }
  }

  func dataStaleAfter() -> Date? { if let data = latestData,
                                      let dataSentAt = data[WatchHelper.keySentAt] as? EpochTimeInt,
                                      let nextReviewAt =
                                      data[WatchHelper.keyNextReviewAt] as? EpochTimeInt {
      let dataSent = Date(timeIntervalSince1970: TimeInterval(dataSentAt))
      let nextReview = Date(timeIntervalSince1970: TimeInterval(nextReviewAt))
      let nextStale = dataSent.addingTimeInterval(dataStaleLimit)
      if nextReview > nextStale {
        return nextReview
      } else {
        return nextStale
      }
    }
    return nil
  }

  func dataIsStale() -> Bool {
    if let staleDate = dataStaleAfter() {
      return Date().distance(to: staleDate) < 0
    }
    return false
  }

  func isDataOutOfDate(userData: UserData?) -> Bool {
    if let data = userData,
       let dataSentAt = data[WatchHelper.keySentAt] as? EpochTimeInt {
      let dataSent = Date(timeIntervalSince1970: TimeInterval(dataSentAt))
      let bestBeforeDate = Date().addingTimeInterval(0 - dataStaleLimit)
      return bestBeforeDate.distance(to: dataSent) < 0
    }
    return true
  }

  func addDelegate(_ delegate: DataManagerDelegate) {
    delegates.append(delegate)
  }

  func removeDelegate(_ delegate: DataManagerDelegate) {
    delegates.removeAll { $0 === delegate }
  }
}
