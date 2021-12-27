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

class UpcomingReviewsViewController: UITableViewController {
  private var services: TKMServices!
  private var dateFormatter = DateFormatter()
  private var model: TableModel?

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - UIView

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    dateFormatter.setLocalizedDateFormatFromTemplate("d MMM ha")
    rerender()
  }

  private func getCumulativeCompositions() -> [ReviewComposition] {
    let subjects = services.localCachingClient.availableSubjects
    var cumulativeData: [ReviewComposition] = []
    for data in subjects.reviewComposition {
      cumulativeData.append(data + (cumulativeData.last ?? ReviewComposition()))
    }
    return cumulativeData
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView)
    model.add(section: "",
              footer: "The numbers on the right are: the total number of reviews, new " +
                "reviews this hour, totals broken down by SRS level: " +
                "apprentice/guru/master/enlightened")
    model.addSection()

    func formatValue(hour: Int) -> String {
      let thisHour = cumulativeCompositions[hour]
      let lastHourReviews = (hour > 0 ? cumulativeCompositions[hour - 1].availableReviews : 0)
      let diff = thisHour.availableReviews - lastHourReviews

      let byCategory = thisHour.countByCategory.sorted {
        $0.key.rawValue < $1.key.rawValue
      }.map { String($1) }.joined(separator: "/")

      return "\(thisHour.availableReviews) (+\(diff)): \(byCategory)"
    }

    let cumulativeCompositions = getCumulativeCompositions()
    for hour in 0 ..< cumulativeCompositions.count {
      // Don't add a row if the number of available reviews was the same as the last hour.
      if hour > 0,
         cumulativeCompositions[hour].availableReviews == cumulativeCompositions[hour - 1]
         .availableReviews { continue }

      let date = Date().addingTimeInterval(TimeInterval(hour * 60 * 60))
      model.add(BasicModelItem(style: .value1,
                               title: dateFormatter.string(from: date),
                               subtitle: formatValue(hour: hour),
                               accessoryType: .none))
    }

    self.model = model
    model.reloadTable()
  }
}
