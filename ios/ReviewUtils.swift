// Copyright 2025 David Sansome
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

func sortReviewItems(items: [ReviewItem], services: TKMServices) -> [ReviewItem] {
  var reviewQueue: [ReviewItem] = items
  reviewQueue.shuffle()
  switch Settings.reviewOrder {
  case .ascendingSRSStage:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.srsStage < b.assignment.srsStage { return true }
      if a.assignment.srsStage > b.assignment.srsStage { return false }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .descendingSRSStage:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.srsStage < b.assignment.srsStage { return false }
      if a.assignment.srsStage > b.assignment.srsStage { return true }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .currentLevelFirst:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.level < b.assignment.level { return false }
      if a.assignment.level > b.assignment.level { return true }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .lowestLevelFirst:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.level < b.assignment.level { return true }
      if a.assignment.level > b.assignment.level { return false }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .newestAvailableFirst:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.availableAt < b.assignment.availableAt { return false }
      if a.assignment.availableAt > b.assignment.availableAt { return true }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .oldestAvailableFirst:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.availableAt < b.assignment.availableAt { return true }
      if a.assignment.availableAt > b.assignment.availableAt { return false }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .longestRelativeWait:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if availableRatio(a.assignment, services: services) < availableRatio(b.assignment,
                                                                           services: services) {
        return false
      }
      if availableRatio(a.assignment, services: services) > availableRatio(b.assignment,
                                                                           services: services) {
        return true
      }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
  case .alternatingSRSStage:
    reviewQueue.sort { (a, b: ReviewItem) -> Bool in
      if a.assignment.srsStage < b.assignment.srsStage { return true }
      if a.assignment.srsStage > b.assignment.srsStage { return false }
      if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
      if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
      return false
    }
    var alternatingReviewQueue = [ReviewItem]()
    var highest = false
    while reviewQueue.count > 0 {
      alternatingReviewQueue
        .append(highest ? reviewQueue.removeLast() : reviewQueue.removeFirst())
      highest = !highest
    }
    reviewQueue = alternatingReviewQueue
  case .random:
    break

  @unknown default:
    fatalError()
  }
  return reviewQueue
}

private func availableRatio(_ assignment: TKMAssignment, services: TKMServices) -> TimeInterval {
  let truncatedDate =
    Date(timeIntervalSince1970: Double((Int(Date().timeIntervalSince1970) / 3600) * 3600))
  let subject = services.localCachingClient.getSubject(id: assignment.subjectID)!
  return truncatedDate.timeIntervalSince(assignment.availableAtDate)
    / assignment.srsStage
    .duration(subject)
}
