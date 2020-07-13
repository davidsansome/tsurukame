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
  var passDates = [Date]()
  var passSystems = [TKMSRSSystem]()

  for assignment in currentLevelAssignments {
    if assignment.subjectType != .radical {
      continue
    }
    guard let subject = services.dataLoader.load(subjectID: Int(assignment.subjectId)),
      let passDate = assignment.passDate(with: services.localCachingClient
        .getSRSSystem(id: subject.srsSystemId)) else {
      continue
    }
    radicalDates.append(passDate)
  }
  radicalDates.sort()
  let lastRadicalGuruTime = max(radicalDates.last?.timeIntervalSinceNow ?? 0, 0)

  for assignment in currentLevelAssignments {
    if assignment.subjectType != .kanji {
      continue
    }
    if !assignment.hasAvailableAt {
      // This kanji is locked, but it might not be essential for level-up
      passDates.append(Date.distantFuture)
      if let srsSystem = services.localCachingClient
        .getSRSSystem(id: services.dataLoader.load(subjectID: Int(assignment.subjectId))?
          .srsSystemId ?? -1) {
        passSystems.append(srsSystem)
      }
      continue
    }
    guard let subject = services.dataLoader.load(subjectID: Int(assignment.subjectId)),
      let srsSystem = services.localCachingClient.getSRSSystem(id: subject.srsSystemId),
      let passDate = assignment.passDate(with: srsSystem) else {
      continue
    }
    passDates.append(passDate)
    passSystems.append(srsSystem)
  }

  // Sort the list of dates and remove the most distant 10%.
  passDates = Array(passDates.sorted().dropLast(Int(Double(passDates.count) * 0.1)))
  passSystems = passSystems
    .sorted { $0.minPassingTime(srsStage: 1) < $1.minPassingTime(srsStage: 1) }

  if let lastPassDate = passDates.last,
    let lastFreshPassTime = passSystems.first?.minPassingTime(srsStage: 1) {
    if lastPassDate == Date.distantFuture {
      // There is still a locked kanji needed for level-up, so we don't know how long
      // the user will take to level up. Use their average level time, minus the time
      // they've spent at this level so far, as an estimate.
      var average = services.localCachingClient!.getAverageRemainingTime()
      // But ensure it can't be less than the time it would take to get a fresh item
      // to Guru, if they've spent longer at the current level than the average.
      average = max(average, lastFreshPassTime + lastRadicalGuruTime)
      return (Date(timeIntervalSinceNow: average), isEstimate: true)
    } else {
      return (lastPassDate, isEstimate: false)
    }
  }

  return (Date(), false)
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
