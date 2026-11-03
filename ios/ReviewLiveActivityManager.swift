// Copyright David Sansome
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

import ActivityKit
import Foundation
import WaniKaniAPI

@available(iOS 16.1, *)
@MainActor
final class ReviewLiveActivityManager {
  static let shared = ReviewLiveActivityManager()
  private var activity: Activity<ReviewLiveActivityAttributes>?

  func update(subject: TKMSubject, type: TKMSubject.TypeEnum, completed: Int, total: Int) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    activity = activity ?? Activity<ReviewLiveActivityAttributes>.activities.first

    let subjectType: String
    let color: String
    switch type {
    case .radical:
      subjectType = "Radical"
      color = "2B6CB0"
    case .kanji:
      subjectType = "Kanji"
      color = "B8346B"
    case .vocabulary:
      subjectType = "Vocabulary"
      color = "74409F"
    default:
      return
    }

    let state = ReviewLiveActivityAttributes.ContentState(
      subject: subject.japanese.isEmpty ? "部" : subject.japanese,
      subjectType: subjectType,
      color: color,
      completed: completed,
      total: total
    )

    if let activity {
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: state, staleDate: nil))
      } else {
        await activity.update(using: state)
      }
    } else {
      do {
        if #available(iOS 16.2, *) {
          activity = try Activity.request(
            attributes: ReviewLiveActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
          )
        } else {
          activity = try Activity.request(
            attributes: ReviewLiveActivityAttributes(), contentState: state
          )
        }
      } catch {
        print("Unable to start review Live Activity: \(error)")
      }
    }
  }

  func end() async {
    guard let activity else { return }
    if #available(iOS 16.2, *) {
      await activity.end(nil, dismissalPolicy: .immediate)
    } else {
      await activity.end(using: nil, dismissalPolicy: .immediate)
    }
    self.activity = nil
  }
}
