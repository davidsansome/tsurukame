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

func createLevelTimeRemainingItem(services: TKMServices,
                                  currentLevelAssignments: [TKMAssignment]) -> TKMModelItem {
  let (finish, isEstimate) = calculateLevelTimeRemaining(services: services,
                                                         currentLevelAssignments: currentLevelAssignments)

  let title = isEstimate ? "Time remaining (estimated)" : "Time remaining"
  let subtitle = finish < Date() ? "Now" : intervalString(finish)
  return TKMBasicModelItem(style: .value1, title: title, subtitle: subtitle)
}

private func calculateLevelTimeRemaining(services: TKMServices,
                                         currentLevelAssignments: [TKMAssignment])
  -> (finish: Date, isEstimate: Bool) {
  var radicalDates = [Date]()
  var guruDates = [Date]()
  var levels = [Int32]()

  for assignment in currentLevelAssignments {
    if assignment.subjectType != .radical {
      continue
    }
    guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID),
      let guruDate = assignment.guruDate(subject: subject) else {
      continue
    }
    radicalDates.append(guruDate)
  }
  radicalDates.sort()
  let lastRadicalGuruTime = max(radicalDates.last?.timeIntervalSinceNow ?? 0, 0)

  for assignment in currentLevelAssignments {
    if assignment.subjectType != .kanji {
      continue
    }
    levels.append(assignment.level)
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
  levels = Array(levels.sorted(by: >).dropLast(Int(Double(levels.count) * 0.1)))

  if let lastGuruDate = guruDates.last, let wkLevel = levels.last {
    if lastGuruDate == Date.distantFuture {
      // There is still a locked kanji needed for level-up, so we don't know how long
      // the user will take to level up. Use their average level time, minus the time
      // they've spent at this level so far, as an estimate.
      var average = averageRemainingLevelTime(services.localCachingClient!)
      // But ensure it can't be less than the time it would take to get a fresh item
      // to Guru, if they've spent longer at the current level than the average.
      average = max(average,
                    SRSStage.apprentice1
                      .minimumTimeUntilGuru(itemLevel: Int(wkLevel)) + lastRadicalGuruTime)
      return (Date(timeIntervalSinceNow: average), isEstimate: true)
    } else {
      return (lastGuruDate, isEstimate: false)
    }
  }

  return (Date(), false)
}

private func averageRemainingLevelTime(_ lcc: LocalCachingClient) -> TimeInterval {
  var timeSpentAtEachLevel = [TimeInterval]()
  for level in lcc.getAllLevelProgressions() {
    timeSpentAtEachLevel.append(level.timeSpentCurrent)
  }
  if timeSpentAtEachLevel.isEmpty {
    return 0
  }

  let currentLevelTime = timeSpentAtEachLevel.last!
  let lastPassIndex = timeSpentAtEachLevel.count - 1

  // Use the median 50% to calculate the average time
  let lowerIndex = lastPassIndex / 4 + (lastPassIndex % 4 == 3 ? 1 : 0)
  let upperIndex = lastPassIndex * 3 / 4 + (lastPassIndex == 1 ? 1 : 0)

  let medianPassRange = timeSpentAtEachLevel[lowerIndex ... upperIndex]
  let averageTime = medianPassRange.reduce(0, +) / Double(medianPassRange.count)
  let remainingTime = averageTime - currentLevelTime

  return remainingTime
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
