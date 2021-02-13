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
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate, LoginViewControllerDelegate {
  var window: UIWindow?

  private var storyboard: UIStoryboard!
  private var navigationController: UINavigationController!
  private var services: TKMServices!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool {
    // Uncomment to slow the animation speed on a real device.
    // window?.layer.speed = .1

    Screenshotter.setUp()

    window?.setInterfaceStyle(Settings.interfaceStyle)
    application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    storyboard = window!.rootViewController!.storyboard
    navigationController = (window!.rootViewController as! UINavigationController)
    services = TKMServices()

    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(logout), name: .logout, object: nil)

    if !Settings.userApiToken.isEmpty, !Settings.userCookie.isEmpty {
      setMainViewControllerAnimated(animated: false, clearUserData: false)
    } else {
      pushLoginViewController()
    }

    return true
  }

  func application(_: UIApplication,
                   willContinueUserActivityWithType userActivityType: String) -> Bool {
    guard let mainVC = findMainViewController() else {
      return true
    }
    if userActivityType == SiriShortcutHelper.ShortcutType.reviews.rawValue {
      if services.localCachingClient.availableReviewCount > 0 {
        // If the user has 0 reviews proceed to the main view controller. If they have
        // 1+ reviews then launch directly into reviews.
        mainVC.performSegue(withIdentifier: "startReviews", sender: nil)
      }
    } else if userActivityType == SiriShortcutHelper.ShortcutType.lessons.rawValue {
      if services.localCachingClient.availableLessonCount > 0 {
        // If the user has 0 lessons proceed to the main view controller. If they have
        // 1+ lessons pending then launch directly into lessons.
        mainVC.performSegue(withIdentifier: "startLessons", sender: nil)
      }
    }
    return true
  }

  private func findMainViewController() -> MainViewController? {
    for vc in navigationController.viewControllers {
      if let vc = vc as? MainViewController {
        return vc
      }
    }
    return nil
  }

  private func pushLoginViewController() {
    let vc = storyboard.instantiateViewController(withIdentifier: "login") as! LoginViewController
    vc.delegate = self
    navigationController.setViewControllers([vc], animated: false)
  }

  private func setMainViewControllerAnimated(animated: Bool, clearUserData: Bool) {
    services.client = WaniKaniAPIClient(apiToken: Settings.userApiToken)
    services.localCachingClient = Screenshotter.createLocalCachingClient(client: services.client,
                                                                         reachability: services
                                                                           .reachability)
    services.client.subjectLevelGetter = services.localCachingClient

    if !Screenshotter.isActive {
      // Ask for notification permissions.
      let unc = UNUserNotificationCenter.current()
      unc.requestAuthorization(options: [.badge, .alert]) { _, _ in }
    }

    let pushMainViewController = { () in
      let vc = self.storyboard
        .instantiateViewController(withIdentifier: "main") as! MainViewController
      vc.setup(services: self.services)
      self.navigationController.setViewControllers([vc], animated: animated)
    }

    // Do a sync before pushing the main view controller if this was a new login.
    if clearUserData {
      services.localCachingClient.clearAllData()
      services.localCachingClient.sync(quick: true, progress: Progress(totalUnitCount: -1))
        .finally {
          pushMainViewController()
        }
    } else {
      pushMainViewController()
    }
  }

  // MARK: - LoginViewControllerDelegate

  func loginComplete() {
    setMainViewControllerAnimated(animated: true, clearUserData: true)
  }

  // MARK: - Notification observers

  @objc
  private func logout(_: Notification?) {
    Settings.userCookie = ""
    Settings.userApiToken = ""
    Settings.userEmailAddress = ""
    services.localCachingClient.clearAllDataAndClose()
    services.localCachingClient = nil

    pushLoginViewController()
  }

  func applicationDidBecomeActive(_: UIApplication) {
    services.reachability.startNotifier()

    if let vc = navigationController.topViewController as? MainViewController {
      vc.refresh(quick: true)
    }
  }

  func applicationWillResignActive(_: UIApplication) {
    services.reachability.stopNotifier()
    updateAppBadgeCount()
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

  private func updateAppBadgeCount() {
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
      if settings.badgeSetting != .enabled {
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
        for hour in 0 ..< upcomingReviews.count {
          let reviews = upcomingReviews[hour]
          if reviews == 0 {
            continue
          }
          cumulativeReviews += reviews

          let triggerTimeInterval = startInterval + (Double(hour) * 60 * 60)
          if triggerTimeInterval <= 0 {
            // UNTimeIntervalNotificationTrigger sometimes crashes with a negative triggerTimeInterval.
            continue
          }
          let identifier = "badge-\(hour)"
          let content = UNMutableNotificationContent()
          if Settings.notificationsAllReviews {
            content
              .body = "\(cumulativeReviews) review\(cumulativeReviews == 1 ? "" : "s") available"
          }
          if Settings.notificationsBadging {
            content.badge = NSNumber(value: cumulativeReviews)
          }
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerTimeInterval,
                                                          repeats: false)
          let request = UNNotificationRequest(identifier: identifier, content: content,
                                              trigger: trigger)
          nc.add(request, withCompletionHandler: nil)
        }
      }
    }
  }
}
