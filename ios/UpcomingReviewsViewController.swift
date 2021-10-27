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

private class UpcomingReviewsDateFormatter: UpcomingReviewsXAxisValueFormatter {
  override init(_ startTime: Date) {
    super.init(startTime)
    dateFormatter.setLocalizedDateFormatFromTemplate("d MMM \(hourFormat)")
  }

  func string(hour: Int) -> String {
    let date = startTime.addingTimeInterval(TimeInterval(hour * 60 * 60))
    return dateFormatter.string(from: date)
  }
}

class UpcomingReviewsViewController: UITableViewController {
  private var services: TKMServices!
  private var date: UpcomingReviewsDateFormatter!
  private var model: TableModel?

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - UIView

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    date = UpcomingReviewsDateFormatter(Date())
    rerender()
  }

  private func getReviewData() -> [ReviewComposition] {
    let subjects = services.localCachingClient.availableSubjects
    var cumulativeData: [ReviewComposition] = []
    for data in subjects.reviewComposition {
      cumulativeData.append(data + (cumulativeData.last ?? ReviewComposition()))
    }
    return cumulativeData
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView),
        reviewData = getReviewData()

    func formatData(hour: Int) -> String {
      let data = reviewData[hour],
          diff = data.availableReviews - (hour > 0 ? reviewData[hour - 1].availableReviews : 0)
      return "\(data.availableReviews) (+\(diff)): " + (Settings.upcomingTypeOverSRS ?
        data.countByType.sorted { $0.key.rawValue < $1.key.rawValue }.reduce("") {
          $0.isEmpty ? "\($1.value)" : "\($0)/\($1.value)"
        } : data.countByCategory.sorted { $0.key.rawValue < $1.key.rawValue }.reduce("") {
          $0.isEmpty ? "\($1.value)" : "\($0)/\($1.value)"
        })
    }

    for hour in 0 ..< reviewData.count {
      if hour > 0,
         reviewData[hour].availableReviews == reviewData[hour - 1].availableReviews { continue }
      model.add(TKMBasicModelItem(style: .value1,
                                  title: date.string(hour: hour),
                                  subtitle: formatData(hour: hour),
                                  accessoryType: .none))
    }

    self.model = model
    model.reloadTable()
  }
}
