// Copyright 2022 David Sansome
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

class AppSettingsViewController: UITableViewController, TKMViewController {
  private var model: TableModel?
  private var notificationHandler: ((Bool) -> Void)?

  // MARK: - TKMViewController

  func canSwipeToGoBack() -> Bool {
    true
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(applicationDidBecomeActive(_:)),
                                           name: UIApplication.didBecomeActiveNotification,
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

    self.model = model
    model.reloadTable()
  }

  @objc private func didTapInterfaceStyle(_: BasicModelItem) {
    performSegue(withIdentifier: "interfaceStyle", sender: self)
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
        center.requestAuthorization(options: [.badge, .alert]) { granted, _ in
          self.notificationHandler?(granted)
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
}
