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

import UIKit
import UserNotifications

typealias NotificationPermissionHandler = (Bool) -> Void

@objcMembers class SettingsViewController: UITableViewController {
  var services: TKMServices!
  var model: TKMTableModel!
  var groupMeaningReadingIndexPath: IndexPath!
  var notificationHandler: NotificationPermissionHandler?
  let disclosureIndicator = UITableViewCell.AccessoryType.disclosureIndicator

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  public func setup(with services: TKMServices) {
    self.services = services
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive),
                                           name: NSNotification
                                             .Name("didBecomeActiveNotification"),
                                           object: nil)
  }

  func rerender() {
    let model = TKMMutableTableModel(tableView: tableView)

    // MARK: - UI Appearance

    if #available(iOS 13.0, *) {
      model.addSection("App")
      model.add(TKMBasicModelItem(style: .value1, title: "UI Appearance",
                                  subtitle: self.interfaceStyleValueText(),
                                  accessoryType: disclosureIndicator, target: self,
                                  action: #selector(didTapInterfaceStyle(item:))))
    }

    // MARK: - Notifications

    model.addSection("Notifications")
    model.add(TKMSwitchModelItem(style: .default,
                                 title: "Notify for all available reviews", subtitle: nil,
                                 on: Settings.notificationsAllReviews, target: self,
                                 action: #selector(notificationsAllReviewsChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .default, title: "Badge the app icon",
                                 subtitle: nil, on: Settings.notificationsBadging, target: self,
                                 action: #selector(notificationsBadgingChanged(switchView:))))

    // MARK: - Lessons

    model.addSection("Lessons")
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Prioritize current level",
                                 subtitle: "Teach items from the current level first",
                                 on: Settings.prioritizeCurrentLevel, target: self,
                                 action: #selector(prioritizeCurrentLevelChanged(switchView:))))
    model.add(TKMBasicModelItem(style: .value1, title: "Lesson item order",
                                subtitle: lessonItemOrderValueText(),
                                accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapLessonOrder(item:))))
    model.add(TKMBasicModelItem(style: .value1, title: "Lesson batch size",
                                subtitle: lessonBatchSizeText(), accessoryType: disclosureIndicator,
                                target: self, action: #selector(didTapLessonBatchSize(item:))))

    // MARK: - Reviews

    model.addSection("Reviews")
    model.add(TKMBasicModelItem(style: .value1, title: "Review order",
                                subtitle: reviewOrderValueText(),
                                accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapReviewOrder(item:))))
    model.add(TKMBasicModelItem(style: .value1, title: "Review batch size",
                                subtitle: reviewBatchSizeText(), accessoryType: disclosureIndicator,
                                target: self, action: #selector(didTapReviewBatchSize(item:))))
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Back-to-back",
                                 subtitle: "Group meaning and reading together",
                                 on: Settings.groupMeaningReading, target: self,
                                 action: #selector(groupMeaningReadingChanged(switchView:))))
    groupMeaningReadingIndexPath = model
      .add(TKMBasicModelItem(style: .value1, title: "Back-to-back order",
                             subtitle: taskOrderValueText(), accessoryType: disclosureIndicator,
                             target: self,
                             action: #selector(didTapTaskOrder(item:))),
           hidden: !Settings.groupMeaningReading)
    model.add(TKMSwitchModelItem(style: .default, title: "Reveal answer automatically",
                                 subtitle: nil, on: Settings.showAnswerImmediately, target: self,
                                 action: #selector(showAnswerImmediatelyChanged(switchView:))))
    model.add(TKMBasicModelItem(style: .default, title: "Fonts", subtitle: nil,
                                accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapFonts(item:))))
    model.add(TKMBasicModelItem(style: .value1, title: "Font size",
                                subtitle: fontSizeValueText(), accessoryType: disclosureIndicator,
                                target: self, action: #selector(didTapFontSize(item:))))
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Exact Match",
                                 subtitle: "Typos won't be allowed to submit",
                                 on: Settings.exactMatch, target: self,
                                 action: #selector(exactMatchChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Ignore & Add Synonym",
                                 subtitle: nil, on: Settings.enableCheats, target: self,
                                 action: #selector(enableCheatsChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Show old mnemonics",
                                 subtitle: "Display old mnemonics alongside new ones",
                                 on: Settings.showOldMnemonic, target: self,
                                 action: #selector(showOldMnemonicChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .subtitle,
                                 title: "Use katakana for onyomi readings", subtitle: nil,
                                 on: Settings.useKatakanaForOnyomi, target: self,
                                 action: #selector(useKatakanaForOnyomiChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Show SRS level indicator",
                                 subtitle: nil, on: Settings.showSRSLevelIndicator, target: self,
                                 action: #selector(showSRSLevelIndicatorChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Show all kanji readings",
                                 subtitle: "Primary reading(s) will be shown in bold",
                                 on: Settings.showAllReadings, target: self,
                                 action: #selector(showAllReadingsChanged(switchView:))))
    let keyboardSwitchItem = TKMSwitchModelItem(style: .subtitle,
                                                title: "Switch to Japanese keyboard",
                                                subtitle: "Automatically switch to a Japanese keyboard to type reading answers",
                                                on: Settings.autoSwitchKeyboard,
                                                target: self,
                                                action: #selector(autoSwitchKeyboardChanged(switchView:)))!
    keyboardSwitchItem.numberOfSubtitleLines = 0
    model.add(keyboardSwitchItem)
    model.add(TKMSwitchModelItem(style: .default, title: "Allow skipping reviews",
                                 subtitle: nil, on: Settings.allowSkippingReviews, target: self,
                                 action: #selector(allowSkippingReviewsChanged(switchView:))))
    let minimizePenaltyItem = TKMSwitchModelItem(style: .subtitle,
                                                 title: "Minimize review penalty",
                                                 subtitle: "Treat reviews answered incorrect multiple times as if answered incorrect once",
                                                 on: Settings.minimizeReviewPenalty, target: self,
                                                 action: #selector(minimizeReviewPenaltyChanged(switchView:)))!
    minimizePenaltyItem.numberOfSubtitleLines = 0
    model.add(minimizePenaltyItem)

    // MARK: - Audio

    model.addSection("Audio")
    model.add(TKMSwitchModelItem(style: .subtitle, title: "Play audio automatically",
                                 subtitle: "When you answer correctly",
                                 on: Settings.playAudioAutomatically, target: self,
                                 action: #selector(playAudioAutomaticallyChanged(switchView:))))
    model.add(TKMBasicModelItem(style: .default, title: "Offline audio", subtitle: nil,
                                accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapOfflineAudio(sender:))))

    // MARK: - Animations

    model.addSection("Animations")
    model.add(TKMSwitchModelItem(style: .default, title: "Particle explosion",
                                 subtitle: nil, on: Settings.animateParticleExplosion, target: self,
                                 action: #selector(animateParticleExplosionChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .default, title: "SRS level up pop-up",
                                 subtitle: nil, on: Settings.animateLevelUpPopup, target: self,
                                 action: #selector(animateLevelUpPopupChanged(switchView:))))
    model.add(TKMSwitchModelItem(style: .default, title: "+1", subtitle: nil,
                                 on: Settings.animatePlusOne, target: self,
                                 action: #selector(animatePlusOneChanged(switchView:))))

    // MARK: - Tsurukame

    model.addSection("Tsurukame")
    model.add(TKMBasicModelItem(style: .subtitle, title: "Export local database",
                                subtitle: "To attach to bug reports or email to the developer",
                                accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapExportDatabase(sender:))))
    let logOutItem = TKMBasicModelItem(style: .default,
                                       title: "Log out", subtitle: nil,
                                       accessoryType: UITableViewCell
                                         .AccessoryType.none,
                                       target: self,
                                       action: #selector(didTapLogOut(sender:)))
    logOutItem.textColor = UIColor.systemRed
    model.add(logOutItem)

    self.model = model
    model.reloadTable()
  }

  // MARK: - Essential Methods

  func interfaceStyleValueText() -> String {
    switch InterfaceStyle(rawValue: Settings.interfaceStyle)! {
    case .system:
      return "System"
    case .light:
      return "Light"
    case .dark:
      return "Dark"
    }
  }

  func lessonItemOrderValueText() -> String {
    var lessonItemOrderText: [String] = []
    for i in Settings.lessonOrder {
      if i == TKMSubject_Type.unknown.rawValue { continue }
      lessonItemOrderText.append(TKMSubjectTypeName(TKMSubject_Type(rawValue: i)!))
    }
    if lessonItemOrderText.count < 3 { lessonItemOrderText.append("Random") }
    return lessonItemOrderText.joined(separator: ", ")
  }

  func lessonBatchSizeText() -> String { String(Settings.lessonBatchSize) }

  func reviewOrderValueText() -> String {
    switch ReviewOrder(rawValue: Settings.reviewOrder)! {
    case .random:
      return "Random"
    case .ascendingSRSStage:
      return "Ascending SRS stage"
    case .descendingSRSStage:
      return "Descending SRS stage"
    case .currentLevelFirst:
      return "Current level first"
    case .lowestLevelFirst:
      return "Lowest level first"
    case .newestAvailableFirst:
      return "Newest available first"
    case .oldestAvailableFirst:
      return "Oldest available first"
    }
  }

  func reviewBatchSizeText() -> String { String(Settings.reviewBatchSize) }

  func taskOrderValueText() -> String {
    if Settings.meaningFirst {
      return "Meaning first"
    } else {
      return "Reading first"
    }
  }

  func fontSizeValueText() -> String { "\(Int(Settings.fontSize * 100))%" }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController!.isNavigationBarHidden = false
    rerender()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    if segue.identifier == "fonts" {
      let vc: TKMFontsViewController = segue.destination as! TKMFontsViewController
      vc.setup(with: services)
    }
  }

  func applicationDidBecomeActive(notification _: Notification) {
    if let notificationHandler = self.notificationHandler {
      let center = UNUserNotificationCenter.current()
      center.getNotificationSettings { (settings: UNNotificationSettings) in
        var granted: Bool = settings.authorizationStatus == UNAuthorizationStatus.authorized
        if #available(iOS 12.0, *) {
          granted = granted || settings.authorizationStatus == UNAuthorizationStatus.provisional
        }
        notificationHandler(granted)
      }
    }
  }

  func promptForNotifications(switchView: UISwitch,
                              handler: @escaping NotificationPermissionHandler) {
    if self.notificationHandler != nil { return }
    if !switchView.isOn {
      handler(false)
      // Clear any existing badge
      UIApplication.shared.applicationIconBadgeNumber = 0
      return
    }
    switchView.setOn(false, animated: true)
    switchView.isEnabled = false

    func __handler(granted: Bool) {
      DispatchQueue.main.async {
        switchView.isEnabled = true
        switchView.setOn(granted, animated: true)
        handler(granted)
      }
    }
    self.notificationHandler = __handler(granted:)

    let notificationHandler: NotificationPermissionHandler = self.notificationHandler!
    let center = UNUserNotificationCenter.current()
    let options: UNAuthorizationOptions = [.badge, .alert]

    center.getNotificationSettings { (settings: UNNotificationSettings) in
      switch settings.authorizationStatus {
      case .authorized:
        fallthrough
      case .provisional:
        notificationHandler(true)
      case .notDetermined:
        center.requestAuthorization(options: options,
                                    completionHandler: { granted, _ in
                                      notificationHandler(granted)
                                    })
      case .denied:
        DispatchQueue.main.async {
          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                    options: Dictionary(), completionHandler: nil)
        }
      @unknown default:
        fatalError()
      }
    }
  }

  // MARK: - Tap UI Appearance

  func didTapInterfaceStyle(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "interfaceStyle", sender: self)
  }

  // MARK: - Tap Notifications

  func notificationsAllReviewsChanged(switchView: UISwitch) {
    promptForNotifications(switchView: switchView,
                           handler: { Settings.notificationsAllReviews = $0 })
  }

  func notificationsBadgingChanged(switchView: UISwitch) {
    promptForNotifications(switchView: switchView,
                           handler: { Settings.notificationsBadging = $0 })
  }

  // MARK: - Tap Lessons

  func prioritizeCurrentLevelChanged(switchView: UISwitch) {
    Settings.prioritizeCurrentLevel = switchView.isOn
  }

  func didTapLessonOrder(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "lessonOrder", sender: self)
  }

  func didTapLessonBatchSize(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "lessonBatchSize", sender: self)
  }

  // MARK: - Tap Reviews

  func didTapReviewOrder(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewOrder", sender: self)
  }

  func didTapReviewItemOrder(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewItemOrder", sender: self)
  }

  func didTapReviewBatchSize(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewBatchSize", sender: self)
  }

  func groupMeaningReadingChanged(switchView: UISwitch) {
    Settings.groupMeaningReading = switchView.isOn
    model.setIndexPath(groupMeaningReadingIndexPath, isHidden: !switchView.isOn)
  }

  func didTapTaskOrder(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "taskOrder", sender: self)
  }

  func showAnswerImmediatelyChanged(switchView: UISwitch) {
    Settings.showAnswerImmediately = switchView.isOn
  }

  func didTapFonts(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "fonts", sender: self)
  }

  func didTapFontSize(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "fontSize", sender: self)
  }

  func exactMatchChanged(switchView: UISwitch) {
    Settings.exactMatch = switchView.isOn
  }

  func enableCheatsChanged(switchView: UISwitch) {
    Settings.enableCheats = switchView.isOn
  }

  func showOldMnemonicChanged(switchView: UISwitch) {
    Settings.showOldMnemonic = switchView.isOn
  }

  func useKatakanaForOnyomiChanged(switchView: UISwitch) {
    Settings.useKatakanaForOnyomi = switchView.isOn
  }

  func showSRSLevelIndicatorChanged(switchView: UISwitch) {
    Settings.showSRSLevelIndicator = switchView.isOn
  }

  func showAllReadingsChanged(switchView: UISwitch) {
    Settings.showAllReadings = switchView.isOn
  }

  func autoSwitchKeyboardChanged(switchView: UISwitch) {
    if switchView.isOn, AnswerTextField.japaneseTextInputMode == nil {
      // The user wants a Japanese keyboard but they don't have one installed.
      let device = UIDevice.current.model
      let message = """
      You must add a Japanese keyboard to your \(device).
      Open Settings then "General ⮕ Keyboard ⮕ Keyboards ⮕ Add New Keyboard."
      """
      let alert = UIAlertController(title: "No Japanese Keyboard", message: message,
                                    preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
      present(alert, animated: true, completion: nil)
      switchView.isOn = false
      return
    }
    Settings.autoSwitchKeyboard = switchView.isOn
  }

  func allowSkippingReviewsChanged(switchView: UISwitch) {
    Settings.allowSkippingReviews = switchView.isOn
  }

  func minimizeReviewPenaltyChanged(switchView: UISwitch) {
    Settings.minimizeReviewPenalty = switchView.isOn
  }

  // MARK: - Tap Audio

  func playAudioAutomaticallyChanged(switchView: UISwitch) {
    Settings.playAudioAutomatically = switchView.isOn
  }

  func didTapOfflineAudio(sender _: Any?) {
    performSegue(withIdentifier: "offlineAudio", sender: self)
  }

  // MARK: - Tap Animations

  func animateParticleExplosionChanged(switchView: UISwitch) {
    Settings.animateParticleExplosion = switchView.isOn
  }

  func animateLevelUpPopupChanged(switchView: UISwitch) {
    Settings.animateLevelUpPopup = switchView.isOn
  }

  func animatePlusOneChanged(switchView: UISwitch) {
    Settings.animatePlusOne = switchView.isOn
  }

  // MARK: - Tap Tsurukame

  func didTapExportDatabase(sender _: Any?) {
    let url = LocalCachingClient.databaseFileUrl
    let c = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    present(c, animated: true, completion: nil)
  }

  func didTapLogOut(sender _: Any?) {
    let c = UIAlertController(title: "Are you sure?", message: nil,
                              preferredStyle: UIAlertController.Style.alert)
    c.addAction(UIAlertAction(title: "Log out", style: UIAlertAction.Style.destructive,
                              handler: { (_: UIAlertAction) in
                                NotificationCenter.default
                                  .post(name: NSNotification
                                    .Name(rawValue: "kLogoutNotification"),
                                    object: self)
                              }))
    c.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
    present(c, animated: true, completion: nil)
  }
}
