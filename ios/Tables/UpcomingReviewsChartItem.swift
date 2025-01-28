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

import Charts
import Foundation

class UpcomingReviewsXAxisValueFormatter: AxisValueFormatter {
  let startTime: Date
  let dateFormatter: DateFormatter
  let hourFormat: String = "ha"

  init(_ startTime: Date) {
    self.startTime = startTime
    dateFormatter = DateFormatter()
    dateFormatter.setLocalizedDateFormatFromTemplate(hourFormat)
  }

  func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
    if value == 0 {
      return ""
    }

    let date = startTime.addingTimeInterval(value * 60 * 60)
    return dateFormatter.string(from: date)
  }
}

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

  var rowHeight: CGFloat? { 120 }
}

class UpcomingReviewsChartCell: TableModelCell {
  @TypedModelItem var item: UpcomingReviewsChartItem

  private let view: CombinedChartView

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    view = CombinedChartView()
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    contentView.addSubview(view)

    view.leftAxis.axisMinimum = 0
    view.leftAxis.granularityEnabled = true
    view.rightAxis.axisMinimum = 0
    view.rightAxis.enabled = true
    view.xAxis.avoidFirstLastClippingEnabled = true
    view.xAxis.drawGridLinesEnabled = false
    view.xAxis.granularityEnabled = true
    view.xAxis.labelPosition = .bottom
    view.rightAxis.drawGridLinesEnabled = false
    view.rightAxis.drawLabelsEnabled = false
    view.legend.enabled = false
    view.isUserInteractionEnabled = false
    view.xAxis.labelTextColor = TKMStyle.Color.label
    view.leftAxis.labelTextColor = TKMStyle.Color.label
  }

  required init!(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    view.frame = contentView.bounds.inset(by: layoutMargins)
  }

  override func update() {
    var hourlyData = [BarChartDataEntry]()
    var cumulativeData = [ChartDataEntry]()

    // Add the reviews pending now.
    var cumulativeReviews = item.currentReviewCount
    cumulativeData.append(ChartDataEntry(x: 0, y: Double(cumulativeReviews)))

    // Add upcoming hourly reviews.
    for i in 0 ..< min(48, item.upcomingReviews.count) {
      let x = i + 1
      let y = item.upcomingReviews[i]

      cumulativeReviews += y
      cumulativeData.append(ChartDataEntry(x: Double(x), y: Double(cumulativeReviews)))

      if y > 0 {
        hourlyData.append(BarChartDataEntry(x: Double(x), y: Double(y)))
      }
    }

    let lineDataSet = LineChartDataSet(cumulativeData)
    lineDataSet.drawValuesEnabled = false
    lineDataSet.drawCircleHoleEnabled = false
    lineDataSet.circleRadius = 1.5
    lineDataSet.colors = [TKMStyle.vocabularyColor2]
    lineDataSet.circleColors = [TKMStyle.vocabularyColor2]

    let barDataSet = BarChartDataSet(hourlyData)
    barDataSet.axisDependency = YAxis.AxisDependency.right
    barDataSet.colors = [TKMStyle.radicalColor2]

    lineDataSet.valueTextColor = TKMStyle.Color.label
    barDataSet.valueTextColor = TKMStyle.Color.label

    let data = CombinedChartData()
    data.lineData = LineChartData(dataSet: lineDataSet)
    data.barData = BarChartData(dataSet: barDataSet)

    view.data = data
    view.xAxis.valueFormatter = UpcomingReviewsXAxisValueFormatter(item.date)

    // valueFormatter must be set after chart.data - see
    // https://github.com/danielgindi/Charts/issues/4690
    barDataSet.valueFormatter = DefaultValueFormatter(decimals: 0)
  }

  override func didSelect() {
    item.tapHandler()
  }
}
