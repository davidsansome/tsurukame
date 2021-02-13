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

class SettingsViewController: UITableViewController {
  private var services: TKMServices!
  private var model: TKMTableModel?
  private var groupMeaningReadingIndexPath: IndexPath?
  private var notificationHandler: ((Bool) -> Void)?

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - UIView

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
    let model = TKMMutableTableModel(tableView: tableView)

    if #available(iOS 13.0, *) {
      model.addSection("App")
      model.add(TKMBasicModelItem(style: .value1,
                                  title: "UI Appearance",
                                  subtitle: Settings.interfaceStyle.description,
                                  accessoryType: .disclosureIndicator,
                                  target: self,
                                  action: #selector(didTapInterfaceStyle(_:))))
    }

    model.addSection("Notifications")
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Notify for all available reviews",
                                 subtitle: nil,
                                 on: Settings.notificationsAllReviews,
                                 target: self,
                                 action: #selector(allReviewsSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Badge the app icon",
                                 subtitle: nil,
                                 on: Settings.notificationsBadging,
                                 target: self,
                                 action: #selector(badgingSwitchChanged(_:))))

    model.addSection("Lessons")
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Prioritize current level",
                                 subtitle: "Teach items from the current level first",
                                 on: Settings.prioritizeCurrentLevel,
                                 target: self,
                                 action: #selector(prioritizeCurrentLevelChanged(_:))))
    model.add(TKMBasicModelItem(style: .value1,
                                title: "Lesson order",
                                subtitle: lessonOrderValueText,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapLessonOrder(_:))))
    model.add(TKMBasicModelItem(style: .value1,
                                title: "Lesson batch size",
                                subtitle: lessonBatchSizeText,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapLessonBatchSize(_:))))

    model.addSection("Reviews")
    model.add(TKMBasicModelItem(style: .value1,
                                title: "Review order",
                                subtitle: reviewOrderValueText,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapReviewOrder(_:))))
    model.add(TKMBasicModelItem(style: .value1,
                                title: "Review batch size",
                                subtitle: "\(Settings.reviewBatchSize.description)",
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapReviewBatchSize(_:))))
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Back-to-back",
                                 subtitle: "Group Meaning and Reading together",
                                 on: Settings.groupMeaningReading,
                                 target: self,
                                 action: #selector(groupMeaningReadingSwitchChanged(_:))))
    groupMeaningReadingIndexPath = model.add(TKMBasicModelItem(style: .value1,
                                                               title: "Back-to-back order",
                                                               subtitle: taskOrderValueText,
                                                               accessoryType: .disclosureIndicator,
                                                               target: self,
                                                               action: #selector(didTapTaskOrder(_:))),
                                             hidden:!Settings
                                               .groupMeaningReading)
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Reveal answer automatically",
                                 subtitle: nil,
                                 on: Settings.showAnswerImmediately,
                                 target: self,
                                 action: #selector(showAnswerImmediatelySwitchChanged(_:))))
    model.add(TKMBasicModelItem(style: .default,
                                title: "Fonts",
                                subtitle: nil,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapFonts(_:))))
    model.add(TKMBasicModelItem(style: .value1,
                                title: "Font size",
                                subtitle: fontSizeValueText,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(fontSizeChanged(_:))))

    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Allow cheating",
                                 subtitle: "Ignore Typos and Add Synonym",
                                 on: Settings.enableCheats,
                                 target: self,
                                 action: #selector(enableCheatsSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Show old mnemonics",
                                 subtitle: "Display old mnemonics alongside new ones",
                                 on: Settings.showOldMnemonic,
                                 target: self,
                                 action: #selector(showOldMnemonicSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Use katakana for onyomi readings",
                                 subtitle: nil,
                                 on: Settings.useKatakanaForOnyomi,
                                 target: self,
                                 action: #selector(useKatakanaForOnyomiSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Show SRS level indicator",
                                 subtitle: nil,
                                 on: Settings.showSRSLevelIndicator,
                                 target: self,
                                 action: #selector(showSRSLevelIndicatorSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Show all kanji readings",
                                 subtitle: "Primary reading(s) will be shown in bold",
                                 on: Settings.showAllReadings,
                                 target: self,
                                 action: #selector(showAllReadingsSwitchChanged(_:))))

    let keyboardSwitchItem = TKMSwitchModelItem(style: .subtitle,
                                                title: "Switch to Japanese keyboard",
                                                subtitle: "Automatically switch to a Japanese keyboard to type reading answers",
                                                on: Settings.autoSwitchKeyboard,
                                                target: self,
                                                action: #selector(autoSwitchKeyboardSwitchChanged(_:)))
    keyboardSwitchItem.numberOfSubtitleLines = 0
    model.add(keyboardSwitchItem)

    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Allow skipping reviews",
                                 subtitle: nil,
                                 on: Settings.allowSkippingReviews,
                                 target: self,
                                 action: #selector(allowSkippingReviewsSwitchChanged(_:))))

    let minimizeReviewPenaltyItem = TKMSwitchModelItem(style: .subtitle,
                                                       title: "Minimize review penalty",
                                                       subtitle:
                                                       "Treat reviews answered incorrect multiple times as if answered incorrect once",
                                                       on: Settings.minimizeReviewPenalty,
                                                       target: self,
                                                       action: #selector(minimizeReviewPenaltySwitchChanged(_:)))
    minimizeReviewPenaltyItem.numberOfSubtitleLines = 0
    model.add(minimizeReviewPenaltyItem)

    model.addSection("Audio")
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Play audio automatically",
                                 subtitle: "When you answer correctly",
                                 on: Settings.playAudioAutomatically,
                                 target: self,
                                 action: #selector(playAudioAutomaticallySwitchChanged(_:))))
    model.add(TKMBasicModelItem(style: .default,
                                title: "Offline audio",
                                subtitle: nil,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapOfflineAudio(_:))))

    model.addSection("Animations", footer: "You can turn off any animations you find distracting")
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Particle explosion",
                                 subtitle: nil,
                                 on: Settings.animateParticleExplosion,
                                 target: self,
                                 action: #selector(animateParticleExplosionSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Level up popup",
                                 subtitle: nil,
                                 on: Settings.animateLevelUpPopup,
                                 target: self,
                                 action: #selector(animateLevelUpPopupSwitchChanged(_:))))
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "+1",
                                 subtitle: nil,
                                 on: Settings.animatePlusOne,
                                 target: self,
                                 action: #selector(animatePlusOneSwitchChanged(_:))))

    model.addSection()
    model.add(TKMBasicModelItem(style: .subtitle,
                                title: "Export local database",
                                subtitle: "To attach to bug reports or email to the developer",
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(didTapSendBugReport(_:))))
    let logOutItem = TKMBasicModelItem(style: .default,
                                       title: "Log out",
                                       subtitle: nil,
                                       accessoryType: .none,
                                       target: self,
                                       action: #selector(didTapLogOut(_:)))
    logOutItem.textColor = .systemRed
    model.add(logOutItem)

    self.model = model
    model.reloadTable()
  }

  // MARK: - Text rendering

  private var lessonOrderValueText: String {
    var parts = [String]()
    for subjectType in Settings.lessonOrder {
      parts.append(subjectType.description)
    }
    return parts.joined(separator: ", ")
  }

  private var lessonBatchSizeText: String {
    "\(Settings.lessonBatchSize)"
  }

  private var reviewOrderValueText: String {
    Settings.reviewOrder.description
  }

  private var taskOrderValueText: String {
    Settings.meaningFirst ? "Meaning first" : "Reading first"
  }

  private var fontSizeValueText: String {
    if Settings.fontSize != 0.0 {
      return "\(Int(Settings.fontSize * 100))%"
    }
    return ""
  }

  // MARK: - Switch change handlers

  @objc private func animateParticleExplosionSwitchChanged(_ switchView: UISwitch) {
    Settings.animateParticleExplosion = switchView.isOn
  }

  @objc private func animateLevelUpPopupSwitchChanged(_ switchView: UISwitch) {
    Settings.animateLevelUpPopup = switchView.isOn
  }

  @objc private func animatePlusOneSwitchChanged(_ switchView: UISwitch) {
    Settings.animatePlusOne = switchView.isOn
  }

  @objc private func prioritizeCurrentLevelChanged(_ switchView: UISwitch) {
    Settings.prioritizeCurrentLevel = switchView.isOn
  }

  @objc private func groupMeaningReadingSwitchChanged(_ switchView: UISwitch) {
    Settings.groupMeaningReading = switchView.isOn
    if let groupMeaningReadingIndexPath = groupMeaningReadingIndexPath {
      model?.setIndexPath(groupMeaningReadingIndexPath, isHidden: !switchView.isOn)
    }
  }

  @objc private func showAnswerImmediatelySwitchChanged(_ switchView: UISwitch) {
    Settings.showAnswerImmediately = switchView.isOn
  }

  @objc private func allowSkippingReviewsSwitchChanged(_ switchView: UISwitch) {
    Settings.allowSkippingReviews = switchView.isOn
  }

  @objc private func minimizeReviewPenaltySwitchChanged(_ switchView: UISwitch) {
    Settings.minimizeReviewPenalty = switchView.isOn
  }

  @objc private func enableCheatsSwitchChanged(_ switchView: UISwitch) {
    Settings.enableCheats = switchView.isOn
  }

  @objc private func showOldMnemonicSwitchChanged(_ switchView: UISwitch) {
    Settings.showOldMnemonic = switchView.isOn
  }

  @objc private func useKatakanaForOnyomiSwitchChanged(_ switchView: UISwitch) {
    Settings.useKatakanaForOnyomi = switchView.isOn
  }

  @objc private func showSRSLevelIndicatorSwitchChanged(_ switchView: UISwitch) {
    Settings.showSRSLevelIndicator = switchView.isOn
  }

  @objc private func autoSwitchKeyboardSwitchChanged(_ switchView: UISwitch) {
    if switchView.isOn, AnswerTextField.japaneseTextInputMode == nil {
      // The user wants a Japanese keyboard but they don't have one installed.
      let device = UIDevice.current.model
      let message = "You must add a Japanese keyboard to your \(device).\nOpen Settings then " +
        "General ⮕ Keyboard ⮕ Keyboards ⮕ Add New Keyboard."
      let ac = UIAlertController(title: "No Japanese keyboard", message: message,
                                 preferredStyle: .alert)
      ac.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
      present(ac, animated: true, completion: nil)
      switchView.isOn = false
      return
    }
    Settings.autoSwitchKeyboard = switchView.isOn
  }

  @objc private func showAllReadingsSwitchChanged(_ switchView: UISwitch) {
    Settings.showAllReadings = switchView.isOn
  }

  @objc private func playAudioAutomaticallySwitchChanged(_ switchView: UISwitch) {
    Settings.playAudioAutomatically = switchView.isOn
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

  // MARK: - Tap handlers

  @objc private func didTapLessonOrder(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "lessonOrder", sender: self)
  }

  @objc private func didTapLessonBatchSize(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "lessonBatchSize", sender: self)
  }

  @objc private func didTapReviewBatchSize(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewBatchSize", sender: self)
  }

  @objc private func fontSizeChanged(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "fontSize", sender: self)
  }

  @objc private func didTapReviewOrder(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewOrder", sender: self)
  }

  @objc private func didTapInterfaceStyle(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "interfaceStyle", sender: self)
  }

  @objc private func didTapFonts(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "fonts", sender: self)
  }

  @objc private func didTapTaskOrder(_: TKMBasicModelItem) {
    performSegue(withIdentifier: "taskOrder", sender: self)
  }

  @objc private func didTapOfflineAudio(_: Any?) {
    performSegue(withIdentifier: "offlineAudio", sender: self)
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "fonts":
      let vc = segue.destination as! TKMFontsViewController
      vc.setup(with: services)

    default:
      break
    }
  }

  @objc private func didTapLogOut(_: Any?) {
    let c = UIAlertController(title: "Are you sure?", message: nil, preferredStyle: .alert)
    c.addAction(UIAlertAction(title: "Log out", style: .destructive, handler: { _ in
      NotificationCenter.default.post(name: .logout, object: self)
    }))
    c.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(c, animated: true, completion: nil)
  }

  @objc private func didTapSendBugReport(_: Any?) {
    let c = UIActivityViewController(activityItems: [LocalCachingClient.databaseUrl()],
                                     applicationActivities: nil)
    present(c, animated: true, completion: nil)
  }
}
