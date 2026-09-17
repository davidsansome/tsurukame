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

class SceneDelegate: UIResponder, UIWindowSceneDelegate, LoginViewControllerDelegate {
  var window: UIWindow?

  private var navigationController: UINavigationController!
  private var services: TKMServices!

  func scene(_: UIScene, willConnectTo _: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    // Tests replace the application delegate with one that doesn't set up any of the app's state,
    // so there's nothing for this scene to attach to.
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let window = window else {
      return
    }
    services = appDelegate.services

    window.setInterfaceStyle(Settings.interfaceStyle)
    navigationController = (window.rootViewController as! UINavigationController)

    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(logout), name: .logout, object: nil)

    if !Settings.userApiToken.isEmpty {
      setMainViewControllerAnimated(animated: false, clearUserData: false)
    } else {
      pushLoginViewController()
    }

    // The app was launched by opening a link or continuing an activity, which arrive here instead
    // of in the scene delegate methods below.
    for context in connectionOptions.urlContexts {
      _ = handleApplink(url: context.url)
    }
    if let userActivity = connectionOptions.userActivities.first {
      startUserActivity(type: userActivity.activityType)
      continueUserActivity(userActivity)
    }
  }

  func sceneDidBecomeActive(_: UIScene) {
    guard services != nil else { return }
    services.reachability.startNotifier()

    if let vc = navigationController.topViewController as? MainViewController {
      vc.refresh(quick: true)
    }
  }

  func sceneWillResignActive(_: UIScene) {
    guard services != nil else { return }
    services.reachability.stopNotifier()
    (UIApplication.shared.delegate as? AppDelegate)?.updateAppBadgeCount()
  }

  func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      _ = handleApplink(url: context.url)
    }
  }

  func scene(_: UIScene, willContinueUserActivityWithType userActivityType: String) {
    startUserActivity(type: userActivityType)
  }

  func scene(_: UIScene, continue userActivity: NSUserActivity) {
    continueUserActivity(userActivity)
  }

  private func startUserActivity(type userActivityType: String) {
    guard let mainVC = findMainWaniKaniTabViewController() else {
      return
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
  }

  @discardableResult
  private func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
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
