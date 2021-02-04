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

func createCurrentLevelReviewTimeItem(services: TKMServices,
                                      currentLevelAssignments: [TKMAssignment]) -> TKMModelItem {
  let finish = calculateCurrentLevelReviewTime(services: services,
                                               currentLevelAssignments: currentLevelAssignments)

  let title = "Next level-up review"
  var subtitle: String
  if finish < Date() {
    subtitle = "Now"
  } else if finish == Date.distantFuture {
    subtitle = "N/A"
  } else {
    subtitle = intervalString(finish)
  }

  return TKMBasicModelItem(style: .value1, title: title, subtitle: subtitle)
}

private func calculateCurrentLevelReviewTime(services: TKMServices,
                                             currentLevelAssignments: [TKMAssignment]) -> Date {
  var guruDates = [Date]()
  var reviewDates = [Date]()

  for assignment in currentLevelAssignments {
    if assignment.subjectType != .kanji {
      continue
    }
    if !assignment.hasAvailableAt {
      // This kanji is locked, but it might not be essential for level-up
      guruDates.append(Date.distantFuture)
      continue
    }
    guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID),
      let guruDate = assignment.guruDate(subject: subject) else {
      continue
    }
    guruDates.append(guruDate)
  }

  // Sort the list of dates and remove the most distant 10%.
  guruDates = Array(guruDates.sorted().dropLast(Int(Double(guruDates.count) * 0.1)))
  let levelKanjiUnlocked = guruDates.last != nil ? (guruDates.last! != Date.distantFuture) : true

  for assignment in currentLevelAssignments {
    if assignment
      .subjectType == .vocabulary || (levelKanjiUnlocked && assignment.subjectType == .radical) {
      continue
    }
    if let reviewDate = assignment.reviewDate {
      if !assignment.isLessonStage {
        reviewDates.append(reviewDate)
      }
    }
  }

  // Sort the list of dates
  reviewDates.sort()

  if let firstReviewDate = reviewDates.first {
    return firstReviewDate
  }
  return Date.distantFuture
}

private func intervalString(_ date: Date) -> String {
  let formatter = DateComponentsFormatter()
  formatter.unitsStyle = DateComponentsFormatter.UnitsStyle.abbreviated

  let componentsBitMask: Set = [Calendar.Component.day, Calendar.Component.hour,
                                Calendar.Component.minute]
  var components = Calendar.current.dateComponents(componentsBitMask, from: Date(), to: date)

  // Only show minutes after there are no hours left.
  if let hour = components.hour, hour > 0 {
    components.minute = 0
  }

  return formatter.string(from: components)!
}
