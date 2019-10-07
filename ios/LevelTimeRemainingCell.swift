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

import Foundation

@objc
class LevelTimeRemainingCell: UITableViewCell {
  private var services: TKMServices?

  @objc
  func setup(withServices services: TKMServices) {
    self.services = services
  }

  @objc
  func update(_ assignments: [TKMAssignment]) {
    var guruDates = [Date]()

    for assignment in assignments {
      if assignment.subjectType != TKMSubject_Type.kanji {
        continue
      }

      if !assignment.hasAvailableAt {
        // This item is still locked so we don't know how long the user will take to
        // unlock it.  Use their average level time, minus the time they've spent at
        // this level so far, as an estimate.
        var average = services!.localCachingClient!.getAverageRemainingLevelTime()

        // But ensure it can't be less than the time it would take to get a fresh item
        // to Guru, if they've spent longer at the current level than the average.
        average = max(average, TKMMinimumTimeUntilGuruSeconds(assignment.level, 1))

        setRemaining(Date(timeIntervalSinceNow: average), isEstimate: true)
        return
      }

      guard let subject = services!.dataLoader.load(subjectID: Int(assignment.subjectId)) else {
        continue
      }

      guruDates.append(assignment.guruDate(for: subject))
    }

    // Sort the list of dates and remove the most distant 10%.
    guruDates.sort()
    guruDates.removeLast(Int(Double(guruDates.count) * 0.1))

    if let lastDate = guruDates.last {
      setRemaining(lastDate, isEstimate: false)
    }
  }

  private func setRemaining(_ finish: Date, isEstimate: Bool) {
    if isEstimate {
      textLabel!.text = "Time remaining (estimated)"
    } else {
      textLabel!.text = "Time remaining"
    }

    if finish < Date() {
      detailTextLabel!.text = "Now"
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
