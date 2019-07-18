//
//  TKMLevel.swift
//  Tsurukame
//
//  Created by André Arko on 7/15/19.
//  Copyright © 2019 David Sansome. All rights reserved.
//

import Foundation

extension DateFormatter {
  func dateFromJsonString(dateString: String) -> Date? {
    // like: "2017-09-28T02:31:35.178938Z"
    self.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
    self.timeZone = TimeZone(abbreviation: "UTC")
    self.locale = Locale(identifier: "en_US_POSIX")
    return self.date(from: dateString)
  }
}

func dateFrom(dict: NSDictionary, keyPath: String) -> Date? {
  if let dateString = dict.value(forKeyPath: keyPath) as? String {
    return DateFormatter().dateFromJsonString(dateString: dateString)
  }

  return nil
}

@objcMembers public class TKMLevel : NSObject {
  let id: Double
  let createdAt: Date
  let level: Int
  let unlockedAt: Date?
  let passedAt: Date?
  let completedAt: Date?
  let abandonedAt: Date?

  public init(dict: NSDictionary) {
    self.id = dict.value(forKey: "id") as! Double
    self.createdAt = dateFrom(dict: dict, keyPath: "data.created_at")!
    self.level = dict.value(forKeyPath: "data.level") as! Int
    self.unlockedAt = dateFrom(dict: dict, keyPath: "data.unlocked_at")
    self.passedAt = dateFrom(dict: dict, keyPath: "data.passed_at")
    self.completedAt = dateFrom(dict: dict, keyPath: "data.completed_at")
    self.abandonedAt = dateFrom(dict: dict, keyPath: "data.abandoned_at")
  }

  public func timeSpentCurrent() -> Double {
    guard unlockedAt != nil else { return 0 }

    if let passedAt = passedAt {
      return passedAt.timeIntervalSince(unlockedAt!)
    } else {
      return Date().timeIntervalSince(unlockedAt!)
    }
  }
}
