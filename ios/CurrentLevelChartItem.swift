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

enum PieSlice: Int {
  case Locked = 0
  case Lesson
  case Novice
  case Apprentice
  case Guru
  static let count = 5

  func label() -> String {
    switch self {
    case .Locked:
      return "Locked"
    case .Lesson:
      return "Lesson"
    case .Novice:
      return TKMSRSStageCategoryName(.novice)
    case .Apprentice:
      return TKMSRSStageCategoryName(.apprentice)
    case .Guru:
      return TKMSRSStageCategoryName(.guru)
    }
  }

  func color(baseColor: UIColor) -> UIColor {
    var saturationMod: CGFloat = 1.0
    switch self {
    case .Locked:
      return UIColor(white: 0.8, alpha: 1.0)
    case .Lesson:
      return UIColor(white: 0.6, alpha: 1.0)
    case .Novice:
      saturationMod = 0.4
    case .Apprentice:
      saturationMod = 0.6
    default:
      break
    }
    var hue: CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var brightness: CGFloat = 0.0
    var alpha: CGFloat = 0.0

    baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return UIColor(hue: hue, saturation: saturation * saturationMod, brightness: brightness, alpha: alpha)
  }
}

func unsetAllLabels(view: ChartViewBase) {
  let dataSet = view.data!.dataSets[0] as! PieChartDataSet
  for other in dataSet.entries as! [PieChartDataEntry] {
    other.label = nil
  }
}

@objc class CurrentLevelChartItem: NSObject, TKMModelItem {
  let dataLoader: DataLoader
  let currentLevelAssignments: [TKMAssignment]

  @objc init(dataLoader: DataLoader, currentLevelAssignments: [TKMAssignment]) {
    self.dataLoader = dataLoader
    self.currentLevelAssignments = currentLevelAssignments
    super.init()
  }

  func cellClass() -> AnyClass! {
    return CurrentLevelChartCell.self
  }

  func rowHeight() -> CGFloat {
    return 120
  }
}

class CurrentLevelChartCell: TKMModelCell {
  var radicalChart: PieChartView!
  var kanjiChart: PieChartView!
  var vocabularyChart: PieChartView!
  var strongDelegate: Delegate

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    strongDelegate = Delegate()
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    radicalChart = createChartView()
    kanjiChart = createChartView()
    vocabularyChart = createChartView()
    strongDelegate.cell = self
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  class Delegate: ChartViewDelegate {
    weak var cell: CurrentLevelChartCell?

    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
      chartValueNothingSelected(chartView)

      // Set this label.
      let pieEntry = entry as! PieChartDataEntry
      pieEntry.label = PieSlice(rawValue: pieEntry.data as! Int)!.label()
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
      unsetAllLabels(view: chartView)

      // Unselect everything in the other charts.
      for otherChart in [cell!.radicalChart!, cell!.kanjiChart!, cell!.vocabularyChart!] {
        if otherChart != chartView {
          otherChart.highlightValue(nil, callDelegate: false)
          unsetAllLabels(view: otherChart)
        }
      }
    }
  }

  private func createChartView() -> PieChartView {
    let view = PieChartView()
    view.chartDescription = nil
    view.legend.enabled = false
    view.holeRadiusPercent = 0.2
    view.delegate = strongDelegate
    contentView.addSubview(view)
    return view
  }

  override func layoutSubviews() {
    var insets = layoutMargins
    insets.bottom = 0
    insets.top = 0

    let frame = contentView.bounds.inset(by: insets)
    let width = frame.width / 3
    var x = frame.minX
    for chart in [radicalChart!, kanjiChart!, vocabularyChart!] {
      chart.frame = CGRect(x: x, y: frame.minY, width: width, height: frame.height)
      x += width
    }
  }

  override func update(with baseItem: TKMModelItem!) {
    let item = baseItem as! CurrentLevelChartItem
    let assignments = item.currentLevelAssignments

    update(chart: radicalChart, subjectType: .radical, withAssignments: assignments)
    update(chart: kanjiChart, subjectType: .kanji, withAssignments: assignments)
    update(chart: vocabularyChart, subjectType: .vocabulary, withAssignments: assignments)
  }

  private func update(chart: PieChartView, subjectType: TKMSubject_Type, withAssignments assignments: [TKMAssignment]) {
    var sliceSizes = [Int](repeating: 0, count: PieSlice.count)
    for assignment in assignments {
      if !assignment.hasSubjectType || assignment.subjectType != subjectType {
        continue
      }

      var slice: PieSlice
      if assignment.isLessonStage {
        slice = .Lesson
      } else if !assignment.hasSrsStage {
        slice = .Locked
      } else if assignment.srsStage <= 1 {
        slice = .Novice
      } else if assignment.srsStage < 5 {
        slice = .Apprentice
      } else {
        slice = .Guru
      }
      sliceSizes[slice.rawValue] += 1
    }

    let baseColor = TKMStyle.color2(forSubjectType: subjectType)
    var values = [PieChartDataEntry]()
    var colors = [UIColor]()

    for i in 0 ..< PieSlice.count {
      if sliceSizes[i] <= 0 {
        continue
      }
      values.append(PieChartDataEntry(value: Double(sliceSizes[i]), data: i))
      colors.append(PieSlice(rawValue: i)!.color(baseColor: baseColor))
    }

    let dataSet = PieChartDataSet(values)
    if #available(iOS 13.0, *) {
      dataSet.valueTextColor = UIColor.secondaryLabel
      dataSet.entryLabelColor = UIColor.label
    } else {
      dataSet.valueTextColor = UIColor.darkGray
      dataSet.entryLabelColor = UIColor.black
    }
    dataSet.valueFont = UIFont.systemFont(ofSize: 10.0)
    dataSet.colors = colors
    dataSet.sliceSpace = 1.0 // Space between slices
    dataSet.selectionShift = 10.0 // Amount to grow when tapped
    dataSet.valueLineColor = nil
    dataSet.valueFormatter = DefaultValueFormatter(decimals: 0)

    chart.data = PieChartData(dataSet: dataSet)
  }
}
