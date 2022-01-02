// Copyright 2022 David Sansome
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
import WaniKaniAPI

private let nonBreakingSpace = "\u{00a0}"

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
                "reviews this hour, totals broken down by SRS level " +
                "(apprentice, guru, master, enlightened) " +
                "and review type (radical, kanji, vocabulary)")
    model.addSection()

    func formatValue(hour: Int) -> NSAttributedString {
      let thisHour = cumulativeCompositions[hour]
      let lastHourReviews = (hour > 0 ? cumulativeCompositions[hour - 1].availableReviews : 0)
      let diff = thisHour.availableReviews - lastHourReviews

      var parts = [TKMFormattedText]()
      parts.append(TKMFormattedText("\(thisHour.availableReviews) (+\(diff)): "))

      let byCategory = thisHour.countByCategory.sorted {
        $0.key.rawValue < $1.key.rawValue
      }.map { nonBreakingSpace + String($1) + nonBreakingSpace }
      if byCategory.count >= 4 {
        parts.append(TKMFormattedText(byCategory[0], format: [.apprentice]))
        parts.append(TKMFormattedText(byCategory[1], format: [.guru]))
        parts.append(TKMFormattedText(byCategory[2], format: [.master]))
        parts.append(TKMFormattedText(byCategory[3], format: [.enlightened]))
      }

      parts.append(TKMFormattedText(nonBreakingSpace))

      let byType = thisHour.countByType.sorted {
        $0.key.rawValue < $1.key.rawValue
      }.map { nonBreakingSpace + String($1) + nonBreakingSpace }
      if byType.count >= 3 {
        parts.append(TKMFormattedText(byType[0], format: [.radical]))
        parts.append(TKMFormattedText(byType[1], format: [.kanji]))
        parts.append(TKMFormattedText(byType[2], format: [.vocabulary]))
      }

      return render(formattedText: parts, standardAttributes: [
        .font: UIFont.systemFont(ofSize: 14),
      ])
    }

    let cumulativeCompositions = getCumulativeCompositions()
    for hour in 0 ..< cumulativeCompositions.count {
      // Don't add a row if the number of available reviews was the same as the last hour.
      if hour > 0,
         cumulativeCompositions[hour].availableReviews == cumulativeCompositions[hour - 1]
         .availableReviews { continue }

      let date = Date().addingTimeInterval(TimeInterval(hour * 60 * 60))
      let item = BasicModelItem(style: .value1,
                                title: dateFormatter.string(from: date),
                                accessoryType: .none)
      item.titleFont = UIFont.systemFont(ofSize: 14)
      item.attributedSubtitle = formatValue(hour: hour)
      model.add(item)
    }

    self.model = model
    model.reloadTable()
  }
}
