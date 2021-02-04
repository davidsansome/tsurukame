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

enum TaskType {
  case reading
  case meaning

  static func random() -> TaskType {
    arc4random_uniform(2) == 0 ? .reading : .meaning
  }
}

@objc
@objcMembers
class ReviewItem: NSObject {
  private class func filterReadyItems(assignments: [TKMAssignment],
                                      localCachingClient: LocalCachingClient,
                                      _ isIncluded: (TKMAssignment) -> Bool) -> [ReviewItem] {
    var ret = [ReviewItem]()
    guard let userInfo = localCachingClient.getUserInfo() else {
      return ret
    }

    for assignment in assignments {
      if !localCachingClient.isValid(subjectId: assignment.subjectID) ||
        (userInfo.hasLevel && userInfo.level < assignment.level) ||
        !isIncluded(assignment) {
        continue
      }
      ret.append(ReviewItem(assignment: assignment))
    }
    return ret
  }

  class func readyForReview(assignments: [TKMAssignment],
                            localCachingClient: LocalCachingClient) -> [ReviewItem] {
    filterReadyItems(assignments: assignments,
                     localCachingClient: localCachingClient) { (assignment) -> Bool in
      assignment.isReviewStage && assignment.availableAtDate.timeIntervalSinceNow < 0
    }
  }

  class func readyForLessons(assignments: [TKMAssignment],
                             localCachingClient: LocalCachingClient) -> [ReviewItem] {
    filterReadyItems(assignments: assignments,
                     localCachingClient: localCachingClient) { (assignment) -> Bool in
      assignment.isLessonStage
    }
  }

  let assignment: TKMAssignment
  var answeredReading = false
  var answeredMeaning = false
  var answer = TKMProgress()

  init(assignment: TKMAssignment) {
    self.assignment = assignment
    answer.assignment = assignment
    answer.isLesson = assignment.isLessonStage
  }

  private func getSubjectTypeIndex(_ subjectType: TKMSubject.TypeEnum) -> Int {
    for (idx, typeValue) in Settings.lessonOrder.enumerated() {
      if typeValue == subjectType {
        return idx
      }
    }
    return 0
  }

  func compareForLessons(other: ReviewItem) -> Bool {
    if assignment.level < other.assignment.level {
      return Settings.prioritizeCurrentLevel ? false : true
    } else if assignment.level > other.assignment.level {
      return Settings.prioritizeCurrentLevel ? true : false
    }

    let myIndex = getSubjectTypeIndex(assignment.subjectType)
    let otherIndex = getSubjectTypeIndex(other.assignment.subjectType)
    if myIndex < otherIndex {
      return true
    } else if myIndex > otherIndex {
      return false
    }
    return assignment.subjectID <= other.assignment.subjectID
  }

  func reset() {
    answer.clearMeaningWrong()
    answer.clearReadingWrong()
    answer.clearMeaningWrongCount()
    answer.clearReadingWrongCount()
    answeredMeaning = false
    answeredReading = false
  }
}
