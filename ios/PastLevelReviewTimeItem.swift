// Copyright 2020 David Sansome
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

@objc
class PastLevelReviewTimeItem: NSObject, TKMModelItem {
  let services: TKMServices
  let pastLevelAssignments: [TKMAssignment]

  @objc init(services: TKMServices, pastLevelAssignments: [TKMAssignment]) {
    self.services = services
    self.pastLevelAssignments = pastLevelAssignments
  }

  func createCell() -> TKMModelCell! {
    return PastLevelReviewTimeCell(style: .value1,
                                   reuseIdentifier: String(describing: PastLevelReviewTimeCell.self))
  }
}

class PastLevelReviewTimeCell: TKMModelCell {
  private var services: TKMServices?

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    detailTextLabel?.textColor = TKMStyle.Color.label
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update(with baseItem: TKMModelItem!) {
    let item = baseItem as! PastLevelReviewTimeItem
    var reviewDates = [Date]()

    for assignment in item.pastLevelAssignments {
      if let reviewDate = assignment.reviewDate {
        if !assignment.isLessonStage {
          reviewDates.append(reviewDate)
        }
      }
    }

    // Sort the list of dates
    reviewDates.sort()

    if let firstReviewDate = reviewDates.first {
      setRemaining(firstReviewDate)
    } else {
      setRemaining(Date.distantFuture)
    }
  }

  private func setRemaining(_ finish: Date) {
    textLabel!.text = "Next past level review"

    if finish < Date() {
      detailTextLabel!.text = "Now"
    } else if finish == Date.distantFuture {
      detailTextLabel!.text = "N/A"
    } else {
      detailTextLabel!.text = intervalString(finish)
    }
  }

  private func intervalString(_ date: Date) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = DateComponentsFormatter.UnitsStyle.abbreviated

    let componentsBitMask: Set = [Calendar.Component.day, Calendar.Component.hour, Calendar.Component.minute]
    var components = Calendar.current.dateComponents(componentsBitMask, from: Date(), to: date)

    // Only show minutes after there are no hours left.
    if let hour = components.hour, hour > 0 {
      components.minute = 0
    }

    return formatter.string(from: components)!
  }
}
