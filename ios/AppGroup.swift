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
#if canImport(WidgetKit)
  import WidgetKit
#endif

// MARK: - CodedWidgetData

public struct CodedWidgetData: Codable {
  public var lessons: Int = -2
  public var reviews: Int = -2
  public var reviewForecast: [Int] = []
  public var date = Date()

  public var isDefault: Bool { lessons == -2 && reviews == -2 }
  public var isSample: Bool { lessons == -1 && reviews == -1 }
}

extension CodedWidgetData {
  init(sampleData: Bool) {
    guard sampleData else {
      self.init()
      return
    }
    self.init(lessons: -1, reviews: -1, reviewForecast: [], date: Date())
  }
}

// MARK: - ReviewCounts

public struct ReviewCounts: Codable, Hashable, Identifiable {
  public var id = UUID()
  public var date: Date
  public var total: Int
  public var new: Int

  static func projectedReviews(from data: CodedWidgetData) -> [ReviewCounts] {
    var date = data.date.hourTruncated!, total = data.reviews, forecast: [ReviewCounts] = []
    for newReviews in data.reviewForecast {
      date += 3600
      total += newReviews
      forecast.append(ReviewCounts(date: date, total: total, new: newReviews))
    }
    return forecast
  }
}

// MARK: - ExpandedWidgetData

public struct ExpandedWidgetData: Codable {
  public var date: Date
  public var lessons: Int
  public var reviewForecast: [ReviewCounts]

  public var reviews: Int { (reviewForecast.first?.total ?? 0) - (reviewForecast.first?.new ?? 0) }

  public func projected(for date: Date) -> ExpandedWidgetData {
    var projectedCounts = reviewForecast
    while projectedCounts.count > 0 {
      guard projectedCounts.first!.date <= date else { break }
      projectedCounts.removeFirst()
    }
    return ExpandedWidgetData(date: date, lessons: lessons, reviewForecast: projectedCounts)
  }

  public func todayForecast(for date: Date) -> [ReviewCounts] {
    var todayForecast: [ReviewCounts] = []
    for forecastEntry in reviewForecast {
      if forecastEntry.date.dateString == date.dateString {
        todayForecast.append(forecastEntry)
      }
    }
    return todayForecast
  }

  public func weekDailyReviewForecast(after date: Date) -> [DailyReviews] {
    var workingDate = "", hasReachedTargetDate = false, dailyReviews: [DailyReviews] = []
    for counts in reviewForecast {
      guard counts.date.dateString != date.dateString else {
        hasReachedTargetDate = true
        continue
      }
      guard hasReachedTargetDate else { continue }
      if counts.date.dateString != workingDate {
        dailyReviews.append(DailyReviews(counts: [counts]))
        workingDate = counts.date.dateString
        continue
      }
      dailyReviews[dailyReviews.count - 1].append(counts)
    }
    return Array(dailyReviews[0 ... 6])
  }
}

// MARK: - DailyReviews

public struct DailyReviews: Codable, Hashable, Identifiable {
  public static let hours = [0, 3, 7, 11, 15, 19, 23]

  public var id = UUID()
  private var counts: [ReviewCounts] = []

  public var filteredCounts: [ReviewCounts] {
    var filtered: [ReviewCounts] = [], new = 0
    for reviewCount in counts {
      new += reviewCount.new
      print(reviewCount.date.hour)
      if DailyReviews.hours.contains(reviewCount.date.hour) {
        filtered.append(ReviewCounts(date: reviewCount.date, total: reviewCount.total, new: new))
        new = 0
      }
    }
    print(filtered)
    return filtered
  }

  public var dayOfWeek: String { counts.first?.date.dayOfWeek ?? "" }
  public var total: Int { counts.last?.total ?? 0 }
  public var initialTotal: Int { (counts.first?.total ?? 0) - (counts.first?.new ?? 0) }
  public var new: Int { total - initialTotal }

  public mutating func append(_ counts: ReviewCounts) { self.counts.append(counts) }

  init(counts: [ReviewCounts]) { self.counts = counts }
}

public extension Date {
  var hour: Int {
    Calendar.current.dateComponents([.hour], from: self).hour!
  }

  var hourTruncated: Date? {
    Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: self)
  }

  var dayOfWeek: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EEE"
    return dateFormatter.string(from: self).capitalized
  }

  var timeString: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: self)
  }

  var dateString: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    return formatter.string(from: self)
  }
}

// MARK: - Data access

public enum AppGroup {
  static let bundle = (Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String)
    .split(separator: ".")[0 ... 2].joined(separator: ".")
  static let wanikani = "group.\(bundle)"
  static let widget = "\(bundle).widget"

  static let containerURL =
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: wanikani)!

  static let dataURL = containerURL.appendingPathComponent("WidgetData.plist")

  @available(iOS 14.0, iOSApplicationExtension 14.0, macCatalyst 14.0, *)
  public static func reloadTimeline() {
    #if canImport(WidgetKit) && (arch(arm64) || arch(i386) || arch(x86_64))
      WidgetCenter.shared.reloadAllTimelines()
      print("Reloaded timeline!")
    #endif
  }

  public static func readGroupData() -> ExpandedWidgetData {
    var d: CodedWidgetData
    if let data = try? Data(contentsOf: AppGroup.dataURL),
       let decodedData = try? PropertyListDecoder().decode(CodedWidgetData.self, from: data) {
      d = decodedData
    } else {
      d = CodedWidgetData(sampleData: true)
    }
    return ExpandedWidgetData(date: d.date, lessons: d.lessons,
                              reviewForecast: ReviewCounts.projectedReviews(from: d))
  }

  public static func writeGroupData(_ lessons: Int, _ reviews: Int, _ reviewForecast: [Int]) {
    let data = CodedWidgetData(lessons: lessons, reviews: reviews, reviewForecast: reviewForecast,
                               date: Date().hourTruncated!)
    let encoder = PropertyListEncoder()
    try! encoder.encode(data).write(to: AppGroup.dataURL)
    if #available(iOS 14.0, iOSApplicationExtension 14.0, macCatalyst 14.0, *) { reloadTimeline() }
  }
}
