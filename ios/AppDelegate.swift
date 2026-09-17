// Copyright 2026 David Sansome
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
import UIKit
import WaniKaniAPI

// The maximum number of local notifications you can add to a NotificationCenter before it starts
// removing old ones.
private let kMaxLocalNotifications = 64

class AppDelegate: UIResponder, UIApplicationDelegate {
  // Owned here rather than by the scene delegate: these outlive any individual scene, and are used
  // for background fetches that happen while no scene is connected.
  private(set) var services: TKMServices!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool {
    Screenshotter.setUp()

    application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    services = TKMServices()

    return true
  }

  func application(_: UIApplication,
                   performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                     -> Void) {
    guard let lcc = services.localCachingClient else {
      completionHandler(.noData)
      return
    }

    lcc.sync(quick: true, progress: Progress(totalUnitCount: -1)).finally {
      self.updateAppBadgeCount()
      completionHandler(.newData)
    }
  }

  func updateAppBadgeCount() {
    if !Settings.notificationsAllReviews, !Settings.notificationsBadging {
      return
    }
    if services.localCachingClient == nil {
      return
    }

    let user = services.localCachingClient.getUserInfo()
    let reviewCount = services.localCachingClient.availableReviewCount
    let upcomingReviews = services.localCachingClient.upcomingReviews

    if user?.hasVacationStartedAt ?? false {
      UIApplication.shared.applicationIconBadgeNumber = 0
      return
    }

    WatchHelper.sharedInstance.updatedData(client: services.localCachingClient)

    let nc = UNUserNotificationCenter.current()
    nc.getNotificationSettings { settings in
      // Don't do anything unless the user has granted some notification permission.
      switch settings.authorizationStatus {
      case .authorized, .ephemeral, .provisional:
        break
      default:
        return
      }

      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = reviewCount
        nc.removeAllPendingNotificationRequests()

        let startDate = NSCalendar.current.nextDate(after: Date(),
                                                    matching: DateComponents(minute: 0, second: 0),
                                                    matchingPolicy: .nextTime)!
        let startInterval = startDate.timeIntervalSinceNow
        var cumulativeReviews = reviewCount
        var notificationsAdded = 0
        for hour in 0 ..< upcomingReviews.count {
          let reviews = upcomingReviews[hour]
          if reviews == 0 {
            continue
          }
          cumulativeReviews += reviews

          let triggerTimeInterval = startInterval + (Double(hour) * 60 * 60)
          if triggerTimeInterval <= 0 {
            // UNTimeIntervalNotificationTrigger sometimes crashes with a negative
            // triggerTimeInterval.
            continue
          }
          let identifier = "badge-\(hour)"
          let content = UNMutableNotificationContent()
          if settings.alertSetting == .enabled, Settings.notificationsAllReviews {
            content.body = "\(cumulativeReviews) review\(cumulativeReviews == 1 ? "" : "s") " +
              "available (\(upcomingReviews[hour]) new)"
          }
          if settings.badgeSetting == .enabled, Settings.notificationsBadging {
            content.badge = NSNumber(value: cumulativeReviews)
          }
          if settings.soundSetting == .enabled, Settings.notificationSounds {
            content.sound = UNNotificationSound.default
          }

          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerTimeInterval,
                                                          repeats: false)
          let request = UNNotificationRequest(identifier: identifier, content: content,
                                              trigger: trigger)

          nc.add(request, withCompletionHandler: nil)
          notificationsAdded += 1
          if notificationsAdded >= kMaxLocalNotifications {
            break
          }
        }
      }
    }
  }
}
