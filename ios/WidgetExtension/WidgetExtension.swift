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

import Intents
import SwiftUI
import WidgetKit

private extension Font {
  static func getFont(size: CGFloat, weight: Font.Weight, monospace: Bool = true) -> Font {
    if monospace {
      return Font.system(size: size, weight: weight, design: .default).monospacedDigit()
    } else {
      return Font.system(size: size, weight: weight, design: .default)
    }
  }
}

extension View {
  func equalSpacedFrame() -> some View {
    frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
  }
}

struct WidgetProvider: TimelineProvider {
  func data(_ date: Date) -> ExpandedWidgetData {
    AppGroup.readGroupData().projected(for: date)
  }

  func placeholder(in _: Context) -> WidgetEntry {
    WidgetEntry(date: Date(), data: data(Date()))
  }

  func getSnapshot(in _: Context, completion: @escaping (WidgetEntry) -> Void) {
    let entry = WidgetEntry(date: Date(), data: data(Date()))
    completion(entry)
  }

  func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    var entries: [WidgetEntry] = []

    // Generate a timeline consisting of now and 24 entries an hour apart.
    let currentDate = Date()
    entries.append(WidgetEntry(date: currentDate, data: data(currentDate)))
    let zeroOffsetDate = currentDate.hourTruncated!
    for hourOffset in 1 ... 24 {
      let entryDate = zeroOffsetDate + Double(3600 * hourOffset)
      let entry = WidgetEntry(date: entryDate, data: data(entryDate))
      entries.append(entry)
    }

    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
  }
}

struct WidgetEntry: TimelineEntry {
  let date: Date
  let data: ExpandedWidgetData
}

struct WidgetView: View {
  var entry: WidgetProvider.Entry
  @Environment(\.widgetFamily) private var widgetFamily

  init(entry: WidgetProvider.Entry) {
    self.entry = entry
  }

  private func gridLayout(columns: Int, spacing: CGFloat = 30,
                          _ bonusFirst: CGFloat = 0,
                          _ bonusLast2: CGFloat = 0,
                          _ bonusLast: CGFloat = 0) -> [GridItem] {
    var items = Array(repeating: GridItem(.fixed(spacing)), count: columns)
    items[0].size = .fixed(spacing + bonusFirst)
    if columns > 2 {
      items[items.count - 2].size = .fixed(spacing + bonusLast2)
      items[items.count - 1].size = .fixed(spacing + bonusLast)
    }
    return items
  }

  var lessonReviewSmallBox: some View {
    VStack {
      HStack(alignment: .center, spacing: 50.0) {
        let largeTitle = Font.getFont(size: 30.0, weight: .bold)
        Text("\(entry.data.lessons)").font(largeTitle)
        Text("\(entry.data.reviews)").font(largeTitle)
      }
      HStack(alignment: .center, spacing: 30.0) {
        Text("Lessons").font(.subheadline)
        Text("Reviews").font(.subheadline)
      }
      Text(entry.date.timeString)
    }.equalSpacedFrame()
  }

  var currentDayForecastSmallBox: some View {
    LazyVGrid(columns: gridLayout(columns: 3, spacing: 28, 25), alignment: .trailing) {
      ForEach(entry.data.todayForecast(for: entry.date)) { forecastEntry in
        if forecastEntry.new != 0 {
          let forecastSmFont = Font.getFont(size: 11, weight: .light)
          Text(forecastEntry.date.timeString).font(forecastSmFont)
          Text("+\(forecastEntry.new)").font(forecastSmFont)
          Text("\(forecastEntry.total) ").font(forecastSmFont)
        }
      }
    }.equalSpacedFrame()
  }

  var weekForecastMediumBox: some View {
    LazyVGrid(columns: gridLayout(columns: 10, spacing: 25, -4, 6), alignment: .trailing) {
      let forecastMedFont = Font.getFont(size: 9.5, weight: .light)
      ForEach([""] + DailyReviews.hours.map { "\($0)" } + ["New", "All"],
              id: \.self) { header in
        Text(header).font(forecastMedFont)
      }
      ForEach(entry.data.weekDailyReviewForecast(after: entry.date)) { dayForecast in
        Text("\(dayForecast.dayOfWeek)").font(forecastMedFont)
        ForEach(dayForecast.filteredCounts) { futureReviews in
          Text("+\(futureReviews.new)").font(forecastMedFont)
        }
        Text("+\(String(dayForecast.new))").font(forecastMedFont)
        Text("\(String(dayForecast.total)) ").font(forecastMedFont)
      }
    }.equalSpacedFrame()
  }

  private var currentDayForecastDefault: some View {
    Text("No additional reviews today! \u{1F389}").equalSpacedFrame()
  }

  private var weekForecastDefault: some View {
    Text("No upcoming reviews this week! \u{1F389}").equalSpacedFrame()
  }

  var body: some View {
    if widgetFamily == .systemSmall {
      lessonReviewSmallBox
    } else if widgetFamily == .systemMedium {
      HStack {
        lessonReviewSmallBox
        Divider()
        if entry.data.reviewForecast.count > 0 { currentDayForecastSmallBox }
        else { currentDayForecastDefault }
      }
    } else {
      VStack {
        HStack {
          lessonReviewSmallBox
          if entry.data.reviewForecast.count > 0 { currentDayForecastSmallBox }
          else { currentDayForecastDefault }
        }
        Divider()
        if entry.data.weekDailyReviewForecast(after: entry.date).count > 0 {
          weekForecastMediumBox
        } else { weekForecastDefault }
      }
    }
  }
}

@main struct WidgetExtension: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: AppGroup.widget,
                        provider: WidgetProvider()) { entry in WidgetView(entry: entry) }
      .configurationDisplayName("Tsurukame Widget")
      .description("Displays lessons, reviews, and forecast!")
      .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct WidgetPreviews: PreviewProvider {
  static var previews: some View {
    WidgetView(entry: WidgetEntry(date: Date(), data: WidgetProvider().data(Date())))
      .previewContext(WidgetPreviewContext(family: .systemLarge))
  }
}
