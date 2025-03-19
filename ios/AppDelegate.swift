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
import UIKit
import WaniKaniAPI

// The maximum number of local notifications you can add to a NotificationCenter before it starts
// removing old ones.
private let kMaxLocalNotifications = 64

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

    if !Settings.userApiToken.isEmpty {
      setMainViewControllerAnimated(animated: false, clearUserData: false)
    } else {
      pushLoginViewController()
    }

    return true
  }

  func application(_: UIApplication,
                   willContinueUserActivityWithType userActivityType: String) -> Bool {
    guard let mainVC = findMainWaniKaniTabViewController() else {
      return true
    }
    if userActivityType == SiriShortcutHelper.ShortcutType.reviews.rawValue {
      if services.localCachingClient.availableReviewCount > 0 {
        // If the user has 0 reviews proceed to the main view controller. If they have
        // 1+ reviews then launch directly into reviews.
        mainVC.perform(segue: StoryboardSegue.Main.startReviews)
      }
    } else if userActivityType == SiriShortcutHelper.ShortcutType.lessons.rawValue {
      if services.localCachingClient.availableLessonCount > 0 {
        // If the user has 0 lessons proceed to the main view controller. If they have
        // 1+ lessons pending then launch directly into lessons.
        mainVC.perform(segue: StoryboardSegue.Main.startLessons)
      }
    }
    return true
  }

  func application(_: UIApplication,
                   continue userActivity: NSUserActivity,
                   restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    switch userActivity.activityType {
    case NSUserActivityTypeBrowsingWeb:
      if let url = userActivity.webpageURL {
        return handleApplink(url: url)
      }
    default:
      break
    }

    return false
  }

  func application(_: UIApplication, open url: URL,
                   options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    handleApplink(url: url)
  }

  private func findMainWaniKaniTabViewController() -> MainWaniKaniTabViewController? {
    for vc in navigationController.viewControllers {
      if let vc = vc as? MainViewController {
        return vc.tabBarViewController?.waniKaniViewController
      }
    }
    return nil
  }

  private func pushLoginViewController() {
    let vc = StoryboardScene.Login.initialScene.instantiate()
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
      unc.requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
    }

    let pushMainViewController = { () in
      let vc = StoryboardScene.Main.initialScene.instantiate()
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

  // MARK: - Applinks

  private func openSubjectDetails(subject: TKMSubject) {
    let vc = StoryboardScene.SubjectDetails.initialScene.instantiate()
    vc.setup(services: services, subject: subject, showHints: true)
    navigationController.pushViewController(vc, animated: true)
  }

  func handleApplink(url: URL) -> Bool {
    // This function handles both universal links (like https://tsurukame.app) and custom URL
    // schemes (like tsurukame:). It ignores the scheme and the host - only looking at the path.
    let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? ""
    let components = path.split(separator: "/")

    guard !components.isEmpty else {
      // An empty path should just bring the app to the foreground, which has been done already.
      return true
    }

    guard let mainVC = findMainWaniKaniTabViewController() else {
      // If the main VC isn't there maybe the user isn't signed in. Don't do anything else.
      return false
    }

    switch components[0] {
    case "reviews":
      mainVC.perform(segue: StoryboardSegue.Main.startReviews)
    case "lessons":
      mainVC.perform(segue: StoryboardSegue.Main.startLessons)
    case "subject":
      if components.count > 1,
         let subjectID = Int64(components[1]),
         let subject = services.localCachingClient.getSubject(id: subjectID) {
        openSubjectDetails(subject: subject)
      }
    case "radical":
      if components.count > 1,
         let subject = services.localCachingClient.getSubject(japanese: String(components[1]),
                                                              type: .radical) {
        openSubjectDetails(subject: subject)
      }
    case "kanji":
      if components.count > 1,
         let subject = services.localCachingClient.getSubject(japanese: String(components[1]),
                                                              type: .kanji) {
        openSubjectDetails(subject: subject)
      }
    case "vocabulary":
      if components.count > 1,
         let subject = services.localCachingClient.getSubject(japanese: String(components[1]),
                                                              type: .vocabulary) {
        openSubjectDetails(subject: subject)
      }
    case "wrap-up":
      if let vcs = navigationController?.viewControllers,
         let reviewContainerVC = vcs
         .first(where: { $0 is ReviewContainerViewController }) as? ReviewContainerViewController {
        reviewContainerVC.reviewVC.wrappingUp = true
      }
    default:
      print("Unsupported applink path: \(url.path)")
      return false
    }

    return true
  }
}
