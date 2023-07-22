// Copyright 2023 David Sansome
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

extension Notification.Name {
  static let reviewsCompleted = Notification.Name("reviewsCompleted")
}

class AppSettingsViewController: UITableViewController, TKMViewController {
  private var model: TableModel?
  private var notificationHandler: ((Bool) -> Void)?

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(applicationDidBecomeActive(_:)),
                                           name: UIApplication.didBecomeActiveNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(handleReviewCompletion),
                                           name: .reviewsCompleted,
                                           object: nil)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    rerender()
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView)

    if #available(iOS 13.0, *) {
      model.addSection()
      model.add(BasicModelItem(style: .value1,
                               title: "UI Appearance",
                               subtitle: Settings.interfaceStyle.description,
                               accessoryType: .disclosureIndicator,
                               target: self,
                               action: #selector(didTapInterfaceStyle(_:))))
    }

    model.add(section: "Notifications")
    model.add(SwitchModelItem(style: .default,
                              title: "Notify for all available reviews",
                              subtitle: nil,
                              on: Settings.notificationsAllReviews,
                              target: self,
                              action: #selector(allReviewsSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .default,
                              title: "Badge the app icon",
                              subtitle: nil,
                              on: Settings.notificationsBadging,
                              target: self,
                              action: #selector(badgingSwitchChanged(_:))))

    model.add(SwitchModelItem(style: .default,
                              title: "Play sound with notifications",
                              subtitle: nil,
                              on: Settings.notificationSounds,
                              target: self,
                              action: #selector(soundSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .default,
                              title: "Critical Alerts",
                              subtitle: "Alert even if phone is muted or on Do Not Disturb",
                              on: Settings.criticalAlerts,
                              target: self,
                              action: #selector(criticalAlertsSwitchChanged(_:))))

    model.add(SwitchModelItem(style: .default,
                              title: "Time Sensitive Notifications",
                              subtitle: "Alert if reviews are not done within half an hour",
                              on: Settings.timeSensitiveNotifications,
                              target: self,
                              action: #selector(timeSensitiveSwitchChanged(_:))))

    self.model = model
    model.reloadTable()
  }

  @objc private func didTapInterfaceStyle(_: BasicModelItem) {
    let vc = SettingChoiceListViewController(setting: Settings.$interfaceStyle,
                                             title: "Interface Style")
    vc.addChoicesFromEnum()
    vc.saveFn = { [unowned vc] in vc.view.window!.setInterfaceStyle($0) }
    navigationController?.pushViewController(vc, animated: true)
  }

  @objc private func allReviewsSwitchChanged(_ switchView: UISwitch) {
    promptForNotifications(switchView: switchView) { granted in
      Settings.notificationsAllReviews = granted
    }
  }

  @objc private func badgingSwitchChanged(_ switchView: UISwitch) {
    promptForNotifications(switchView: switchView) { granted in
      Settings.notificationsBadging = granted
    }
  }

  @objc private func soundSwitchChanged(_ switchView: UISwitch) {
    promptForNotifications(switchView: switchView) { granted in
      Settings.notificationSounds = granted
    }
  }

  @objc private func criticalAlertsSwitchChanged(_ switchView: UISwitch) {
    promptForNotifications(switchView: switchView) { granted in
      Settings.criticalAlerts = granted
    }
  }

  @objc private func timeSensitiveSwitchChanged(_ switchView: UISwitch) {
    promptForNotifications(switchView: switchView) { granted in
      Settings.timeSensitiveNotifications = granted
      // If granted, schedule a notification to be triggered in 30 minutes if reviews are not done
      if granted {
        self.scheduleTimeSensitiveNotification()
      }
    }
  }

  @objc private func handleReviewCompletion() {
    reviewCompleted()
  }

  private func scheduleTimeSensitiveNotification() {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = "Time Sensitive Alert!"
    content.body = "You haven't done your reviews within the last half an hour!"
    content.sound = UNNotificationSound.default
    content.categoryIdentifier = "timeSensitiveNotification"

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1800, repeats: false)
    let request = UNNotificationRequest(identifier: "timeSensitiveNotificationId",
                                        content: content, trigger: trigger)

    center.add(request) { error in
      if let error = error {
        print("Error scheduling time sensitive notification: \(error)")
      }
    }
  }

  func reviewCompleted() {
    // Assuming `Settings.timeSensitiveNotifications` is a boolean that indicates whether Time Sensitive Notifications are enabled
    if Settings.timeSensitiveNotifications {
      cancelTimeSensitiveNotification()
    }
  }

  // This function will cancel the time-sensitive notification
  func cancelTimeSensitiveNotification() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["timeSensitiveNotificationId"])
  }

  private func promptForNotifications(switchView: UISwitch,
                                      handler: @escaping (Bool) -> Void) {
    if notificationHandler != nil {
      return
    }
    if !switchView.isOn {
      handler(false)
      // Clear any existing badge
      UIApplication.shared.applicationIconBadgeNumber = 0
      return
    }

    switchView.setOn(false, animated: true)
    switchView.isEnabled = false

    notificationHandler = { granted in
      DispatchQueue.main.async {
        switchView.isEnabled = true
        switchView.setOn(granted, animated: true)
        handler(granted)
        self.notificationHandler = nil
      }
    }

    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        self.notificationHandler?(true)
      case .notDetermined:
        if #available(iOS 15.0, *) {
          center
            .requestAuthorization(options: [.badge, .alert, .sound, .criticalAlert,
                                            .provisional,
                                            .timeSensitive]) { granted, _ in
              self.notificationHandler?(granted)
            }
        } else {
          // Fallback on earlier versions
          center
            .requestAuthorization(options: [.badge, .alert, .sound, .criticalAlert,
                                            .provisional]) { granted, _ in
              self.notificationHandler?(granted)
            }
        }
      case .denied:
        DispatchQueue.main.async {
          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:],
                                    completionHandler: nil)
        }
      default:
        break
      }
    }
  }

  @objc private func applicationDidBecomeActive(_: NSNotification) {
    if notificationHandler == nil {
      return
    }
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      var granted = settings.authorizationStatus == .authorized
      if #available(iOS 12.0, *) {
        granted = granted || settings.authorizationStatus == .provisional
      }
      self.notificationHandler?(granted)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: .reviewsCompleted, object: nil)
  }
}
