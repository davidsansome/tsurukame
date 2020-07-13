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
import UserNotifications

@UIApplicationMain @objcMembers class AppDelegate: NSObject, UIApplicationDelegate,
  LoginViewControllerDelegate {
  var navigationController: UINavigationController!
  var services: TKMServices!
  var storyboard: UIStoryboard!
  var window: UIWindow?

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil)
    -> Bool {
    // Uncomment to slow the animation speed on a real device.
    // window?.layer.speed = 0.1
    Screenshotter.setUp()

    window?.setInterfaceStyle(Settings.interfaceStyle)
    application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    storyboard = window?.rootViewController?.storyboard
    navigationController = window?.rootViewController as? UINavigationController
    services = TKMServices()

    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(logout),
                   name: NSNotification.Name(rawValue: "kLogoutNotification"), object: nil)
    nc.addObserver(self, selector: #selector(userInfoChanged),
                   name: NSNotification
                     .Name(rawValue: "LocalCachingClientUserInfoChangedNotification"),
                   object: nil)

    if Settings.userApiToken != "", Settings.userCookie != "" {
      setMainViewController(animated: false, clearUserData: false)
    } else {
      pushLoginViewController()
    }
    return true
  }

  func application(_: UIApplication,
                   willContinueUserActivityWithType userActivityType: String) -> Bool {
    if userActivityType == SiriShortcutHelper.ShortcutTypeReviews {
      if services.localCachingClient.availableReviewCount > 0 {
        // If the user has 0 reviews proceed to main view controller. Otherwise, go straight to reviews.
        findMainViewController()?.performSegue(withIdentifier: "startReviews", sender: nil)
      }
    } else if userActivityType == SiriShortcutHelper.ShortcutTypeLessons {
      if services.localCachingClient.availableLessonCount > 0 {
        findMainViewController()?.performSegue(withIdentifier: "startLessons", sender: nil)
      }
    }
    return true
  }

  func pushLoginViewController() {
    let loginVC = storyboard
      .instantiateViewController(withIdentifier: "login") as! LoginViewController
    loginVC.delegate = self
    navigationController.setViewControllers([loginVC], animated: false)
  }

  func setMainViewController(animated: Bool, clearUserData: Bool) {
    let client = Client(apiToken: Settings.userApiToken, cookie: Settings.userCookie,
                        dataLoader: services.dataLoader)
    services.localCachingClient = Screenshotter.localCachingClientClass.init(client: client,
                                                                             dataLoader: services
                                                                               .dataLoader,
                                                                             reachability: services
                                                                               .reachability)

    if !Screenshotter.isActive {
      // Ask for notification permissions.
      UNUserNotificationCenter.current()
        .requestAuthorization(options: [.badge, .alert], completionHandler: { _, _ in })
    }

    func pushMainViewController() {
      let mainVC = storyboard
        .instantiateViewController(withIdentifier: "main") as! MainViewController
      mainVC.setup(services: services)
      navigationController.setViewControllers([mainVC], animated: animated)
    }

    // Do a sync before pushing the main view controller if this was a new login.
    if clearUserData {
      services.localCachingClient.clearAllData()
      services.localCachingClient.sync(quickly: true) { (progress: Double) in
        if progress == 1.0 { pushMainViewController() }
      }
    } else {
      userInfoChanged()
      pushMainViewController()
    }
  }

  func loginComplete() {
    setMainViewController(animated: true, clearUserData: true)
  }

  func logout() {
    Settings.userCookie = ""
    Settings.userApiToken = ""
    Settings.userEmailAddress = ""
    services.localCachingClient.clearAllDataAndClose()
    services.localCachingClient = nil
    pushLoginViewController()
  }

  func applicationDidBecomeActive(_: UIApplication) {
    try! services.reachability.startNotifier()
    if let mainVC = navigationController.topViewController as? MainViewController {
      mainVC.refresh(quick: true)
    }
  }

  func applicationWillResignActive(_: UIApplication) {
    services.reachability.stopNotifier()
    updateAppBadgeCount()
  }

  func application(_: UIApplication,
                   performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                     -> Void) {
    guard let localCachingClient = services.localCachingClient else {
      completionHandler(.noData)
      return
    }
    localCachingClient.sync(quickly: true) { [weak self] (progress: Double) in
      if progress == 1.0 {
        self?.updateAppBadgeCount()
        completionHandler(.newData)
      }
    }
  }

  func updateAppBadgeCount() {
    let reviewCount = services.localCachingClient.availableReviewCount
    let upcomingReviews = services.localCachingClient.upcomingReviews
    let user = services.localCachingClient.getUserInfo()!

    if user.hasVacationStartedAt {
      UIApplication.shared.applicationIconBadgeNumber = 0
      return
    }

    WatchHelper.sharedInstance.updatedData(client: services.localCachingClient)
    if !Settings.notificationsAllReviews, !Settings.notificationsBadging { return }

    func updateClosure() {
      UIApplication.shared.applicationIconBadgeNumber = Int(reviewCount)
      UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

      let startDate = Calendar.current.nextDate(after: Date(), matching: DateComponents(minute: 0),
                                                matchingPolicy: .nextTime)!
      let startInterval = startDate.timeIntervalSinceNow
      var cumulativeReviews = reviewCount
      for hour in 0 ..< upcomingReviews.count {
        let reviews = upcomingReviews[hour]
        if reviews == 0 { continue }

        cumulativeReviews += reviews
        let triggerTimeInterval = startInterval + Double(hour * 3600)
        if triggerTimeInterval <= 0 { continue } // Avoid possible crashes

        let identifier = "badge-\(hour)"
        let content = UNMutableNotificationContent()
        if Settings.notificationsAllReviews {
          content.body = "\(cumulativeReviews) review\(cumulativeReviews == 1 ? "" : "s") available"
        }
        if Settings.notificationsBadging {
          content.badge = NSNumber(value: cumulativeReviews)
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerTimeInterval,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
      }
    }

    UNUserNotificationCenter.current()
      .getNotificationSettings { (settings: UNNotificationSettings) in
      if settings.badgeSetting == .enabled {
        DispatchQueue.main.async(execute: updateClosure)
      }
    }
  }

  func userInfoChanged() {
    services.dataLoader
      .maxLevelGrantedBySubscription = Int(services.localCachingClient.getUserInfo()!
        .maxLevelGrantedBySubscription)
  }

  func findMainViewController() -> MainViewController? {
    for viewController in navigationController.viewControllers {
      if let mainVC = viewController as? MainViewController {
        return mainVC
      }
    }
    return nil
  }
}
