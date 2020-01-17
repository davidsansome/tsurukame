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

import CoreSpotlight
import Foundation
import Intents
import MobileCoreServices

@objc class SiriShortcutHelper: NSObject {
  @objc static let ShortcutTypeReviews = "com.tsurukame.reviews"
  @objc static let ShortcutTypeLessons = "com.tsurukame.lessons"

  @objc public static let shared = SiriShortcutHelper()

  @objc(attachShortcutActivity:type:)
  func attachShortcutActivity(_ vc: UIViewController, type: String) {
    if #available(iOS 12.0, *) {
      vc.userActivity = newShortcutActivity(type: type)
      vc.userActivity?.becomeCurrent()
    }
  }

  @available(iOS 12.0, *)
  func newShortcutActivity(type: String) -> NSUserActivity {
    let activity = NSUserActivity(activityType: type)
    activity.persistentIdentifier = NSUserActivityPersistentIdentifier(type)
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true

    configureType(type, activity: activity)

    return activity
  }

  func configureType(_ type: String, activity: NSUserActivity) {
    let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
    switch type {
    case SiriShortcutHelper.ShortcutTypeReviews:
      activity.title = "Start Wanikani Reviews"
      if #available(iOS 12.0, *) {
        activity.suggestedInvocationPhrase = "Start Wanikani Reviews"
      }
      attributes.contentDescription = "Keep it up and burn every one"
    case SiriShortcutHelper.ShortcutTypeLessons:
      activity.title = "Start Wanikani Lessons"
      if #available(iOS 12.0, *) {
        activity.suggestedInvocationPhrase = "Start Wanikani Lessons"
      }
      attributes.contentDescription = "Learn something new"
    default:
      NSLog("unknown type")
    }
    activity.contentAttributeSet = attributes
  }
}
