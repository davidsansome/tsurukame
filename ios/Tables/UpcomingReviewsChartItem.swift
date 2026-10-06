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

// Number of hourly bars shown, including the "now" bar.
private let kHours = 24

class UpcomingReviewsChartItem: TableModelItem {
  let upcomingReviews: [Int]
  let currentReviewCount: Int
  let date: Date
  let tapHandler: () -> Void

  init(upcomingReviews: [Int], currentReviewCount: Int, date: Date,
       tapHandler: @escaping () -> Void) {
    self.upcomingReviews = upcomingReviews
    self.currentReviewCount = currentReviewCount
    self.date = date
    self.tapHandler = tapHandler
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: UpcomingReviewsChartCell.self)
  }

  var rowHeight: CGFloat? { 150 }

  // Reviews in each hour: the ones available now, then the next 23 hours.
  var hourlyCounts: [Int] {
    [currentReviewCount] + upcomingReviews.prefix(kHours - 1)
  }

  var upcomingTotal: Int {
    upcomingReviews.prefix(kHours - 1).reduce(0, +)
  }
}

class UpcomingReviewsChartCell: TableModelCell {
  @TypedModelItem var item: UpcomingReviewsChartItem

  private let summaryLabel = UILabel()
  private let bars = UpcomingReviewsBarsView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    summaryLabel.font = UIFont.systemFont(ofSize: 13)
    summaryLabel.textColor = TKMStyle.Color.grey33
    summaryLabel.textAlignment = .right

    for view in [summaryLabel, bars] {
      view.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(view)
    }
    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      summaryLabel.topAnchor.constraint(equalTo: margins.topAnchor),
      summaryLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      summaryLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      bars.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 8),
      bars.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      bars.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      bars.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
    ])

    isAccessibilityElement = true
    accessibilityTraits = .button
  }

  required init!(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    let total = item.upcomingTotal
    summaryLabel.text = total == 0 ? "Nothing more in the next 24 hours" :
      "+\(total) in the next 24 hours"
    bars.counts = item.hourlyCounts
    bars.startDate = item.date
    accessibilityLabel = "Upcoming reviews: \(item.currentReviewCount) now, " +
      "\(total) more in the next 24 hours"
    accessibilityHint = "Shows the full forecast"
  }

  override func didSelect() {
    item.tapHandler()
  }
}

// Hourly bars with the current hour in the accent colour and time labels every six hours.
private class UpcomingReviewsBarsView: UIView {
  var counts = [Int]() {
    didSet { setNeedsDisplay() }
  }

  var startDate = Date() {
    didSet { setNeedsDisplay() }
  }

  private let barColor = UIColor { tc in
    tc.userInterfaceStyle == .dark ? UIColor(red: 0.788, green: 0.757, blue: 0.694, alpha: 1)
      : TKMStyle.Color.night
  }

  private let formatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("ha")
    return f
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = .clear
    contentMode = .redraw
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_: CGRect) {
    guard let context = UIGraphicsGetCurrentContext(), !counts.isEmpty else { return }

    let labelHeight: CGFloat = 16
    let chartHeight = bounds.height - labelHeight - 6
    let gap: CGFloat = 4
    let barWidth = (bounds.width - gap * CGFloat(kHours - 1)) / CGFloat(kHours)
    let maxCount = max(counts.max() ?? 1, 1)

    // Baseline.
    context.setFillColor(TKMStyle.Color.grey80.resolvedColor(with: traitCollection).cgColor)
    context.fill(CGRect(x: 0, y: chartHeight, width: bounds.width, height: 1))

    for (i, count) in counts.enumerated() {
      let height = count == 0 ? 2 : max(4, chartHeight * CGFloat(count) / CGFloat(maxCount))
      let rect = CGRect(x: CGFloat(i) * (barWidth + gap), y: chartHeight - height,
                        width: barWidth, height: height)
      let color: UIColor = i == 0 ? TKMStyle.Color.accent :
        (count == 0 ? TKMStyle.Color.grey80 : barColor)
      context.setFillColor(color.resolvedColor(with: traitCollection).cgColor)
      UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                   cornerRadii: CGSize(width: 3, height: 3)).fill()
    }

    // Labels: "Now N" under the first bar, then the hour every six hours.
    let labelY = chartHeight + 6
    let font = UIFont.systemFont(ofSize: 11)
    let secondary = TKMStyle.Color.grey33.resolvedColor(with: traitCollection)
    let accent = TKMStyle.Color.accent.resolvedColor(with: traitCollection)
    ("Now \(counts[0])" as NSString).draw(at: CGPoint(x: 0, y: labelY), withAttributes: [
      .font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: accent,
    ])
    for hour in stride(from: 6, to: kHours, by: 6) {
      let text = formatter.string(from: startDate.addingTimeInterval(Double(hour) * 3600))
        as NSString
      let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: secondary]
      let width = text.size(withAttributes: attributes).width
      let centre = CGFloat(hour) * (barWidth + gap) + barWidth / 2
      text.draw(at: CGPoint(x: min(centre - width / 2, bounds.width - width), y: labelY),
                withAttributes: attributes)
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    setNeedsDisplay()
  }
}
