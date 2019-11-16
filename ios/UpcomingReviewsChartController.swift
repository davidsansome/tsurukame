// Copyright 2019 David Sansome
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

class UpcomingReviewsXAxisValueFormatter: IAxisValueFormatter {
  let startTime: Date
  let dateFormatter: DateFormatter

  init(_ startTime: Date) {
    self.startTime = startTime
    dateFormatter = DateFormatter()
    dateFormatter.setLocalizedDateFormatFromTemplate("ha")
  }

  func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
    if value == 0 {
      return ""
    }

    let date = startTime.addingTimeInterval(value * 60 * 60)
    return dateFormatter.string(from: date)
  }
}

@objc
class UpcomingReviewsChartController: NSObject {
  private let view: CombinedChartView

  @objc init(chartView: CombinedChartView) {
    chartView.leftAxis.axisMinimum = 0
    chartView.leftAxis.granularityEnabled = true
    chartView.rightAxis.axisMinimum = 0
    chartView.rightAxis.enabled = true
    chartView.xAxis.avoidFirstLastClippingEnabled = true
    chartView.xAxis.drawGridLinesEnabled = false
    chartView.xAxis.granularityEnabled = true
    chartView.xAxis.labelPosition = .bottom
    chartView.rightAxis.drawGridLinesEnabled = false
    chartView.rightAxis.drawLabelsEnabled = false
    chartView.legend.enabled = false
    chartView.chartDescription = nil
    chartView.isUserInteractionEnabled = false

    view = chartView
    super.init()
  }

  @objc public func update(_ upcomingReviews: [Int], currentReviewCount: Int, at date: Date) {
    var hourlyData = [BarChartDataEntry]()
    var cumulativeData = [ChartDataEntry]()

    // Add the reviews pending now.
    var cumulativeReviews = currentReviewCount
    cumulativeData.append(ChartDataEntry(x: 0, y: Double(cumulativeReviews)))

    // Add upcoming hourly reviews.
    for i in 0 ..< upcomingReviews.count {
      let x = i + 1
      let y = upcomingReviews[i]

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
    barDataSet.valueFormatter = DefaultValueFormatter(decimals: 0)

    let data = CombinedChartData()
    data.lineData = LineChartData(dataSet: lineDataSet)
    data.barData = BarChartData(dataSet: barDataSet)

    view.data = data
    view.xAxis.valueFormatter = UpcomingReviewsXAxisValueFormatter(date)
  }
}
