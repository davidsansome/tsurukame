// Copyright 2024 David Sansome
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

class ReviewSettingsViewController: UITableViewController, TKMViewController {
  private var services: TKMServices!
  private var model: TableModel?
  private var groupMeaningReadingIndexPath: IndexPath?
  private var ankiModeCombineReadingMeaningIndexPath: IndexPath?

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    rerender()
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView)

    model.addSection()
    model.add(BasicModelItem(style: .value1,
                             title: "Order",
                             subtitle: reviewOrderValueText,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapReviewOrder(_:))))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Back-to-back",
                              subtitle: "Group Meaning and Reading together",
                              on: Settings.groupMeaningReading,
                              target: self,
                              action: #selector(groupMeaningReadingSwitchChanged(_:))))
    groupMeaningReadingIndexPath = model.add(BasicModelItem(style: .value1,
                                                            title: "Back-to-back order",
                                                            subtitle: taskOrderValueText,
                                                            accessoryType: .disclosureIndicator,
                                                            target: self,
                                                            action: #selector(didTapTaskOrder(_:))),
                                             hidden:!Settings
                                               .groupMeaningReading)
    model.add(BasicModelItem(style: .value1,
                             title: "Batch size",
                             subtitle: "\(Settings.reviewBatchSize.description)",
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapReviewBatchSize(_:))))

    model.add(section: "Display")
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show SRS level indicator",
                              subtitle: nil,
                              on: Settings.showSRSLevelIndicator,
                              target: self,
                              action: #selector(showSRSLevelIndicatorSwitchChanged(_:))))
    model.add(BasicModelItem(style: .default,
                             title: "Fonts",
                             subtitle: nil,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapFonts(_:))))
    model.add(BasicModelItem(style: .value1,
                             title: "Font size",
                             subtitle: fontSizeValueText,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(fontSizeChanged(_:))))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show minutes for next level-up review",
                              subtitle: nil,
                              on: Settings.showMinutesForNextLevelUpReview,
                              target: self,
                              action: #selector(showMinutesForNextLevelUpReview(_:))))

    model.add(section: "Answers & marking")
    let keyboardSwitchItem = SwitchModelItem(style: .subtitle,
                                             title: "Switch to Japanese keyboard",
                                             subtitle: "Automatically switch to a Japanese keyboard to type reading answers",
                                             on: Settings.autoSwitchKeyboard,
                                             target: self,
                                             action: #selector(autoSwitchKeyboardSwitchChanged(_:)))
    keyboardSwitchItem.numberOfSubtitleLines = 0
    model.add(keyboardSwitchItem)
    let revealAnswerItem = SwitchModelItem(style: .subtitle,
                                           title: "Reveal answer automatically",
                                           subtitle: nil,
                                           on: Settings.showAnswerImmediately,
                                           target: self,
                                           action: #selector(showAnswerImmediatelySwitchChanged(_:)))
    revealAnswerItem.numberOfSubtitleLines = 0
    model.add(revealAnswerItem)
    let fullAnswerItem = SwitchModelItem(style: .subtitle,
                                         title: "Reveal full answer",
                                         subtitle: "Instead of hiding behind a 'Show more information' button",
                                         on: Settings.showFullAnswer, target: self,
                                         action: #selector(showFullAnswerSwitchChanged(_:)))
    fullAnswerItem.numberOfSubtitleLines = 0
    model.add(fullAnswerItem)
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Exact match",
                              subtitle: "Requires typing in answers exactly correct",
                              on: Settings.exactMatch,
                              target: self,
                              action: #selector(exactMatchSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Allow cheating",
                              subtitle: "Ignore Typos and Add Synonym",
                              on: Settings.enableCheats,
                              target: self,
                              action: #selector(enableCheatsSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .default,
                              title: "Allow skipping",
                              subtitle: nil,
                              on: Settings.allowSkippingReviews,
                              target: self,
                              action: #selector(allowSkippingReviewsSwitchChanged(_:))))

    let minimizeReviewPenaltyItem = SwitchModelItem(style: .subtitle,
                                                    title: "Minimize review penalty",
                                                    subtitle:
                                                    "Treat reviews answered incorrect multiple times as if answered incorrect once",
                                                    on: Settings.minimizeReviewPenalty,
                                                    target: self,
                                                    action: #selector(minimizeReviewPenaltySwitchChanged(_:)))
    minimizeReviewPenaltyItem.numberOfSubtitleLines = 0
    model.add(minimizeReviewPenaltyItem)
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Anki mode",
                              subtitle: "Do reviews without typing answers",
                              on: Settings.ankiMode,
                              target: self,
                              action: #selector(ankiModeSwitchChanged(_:))))

    let ankiModeCombineReadingMeaning = SwitchModelItem(style: .subtitle,
                                                        title: "Combine Reading + Meaning",
                                                        subtitle: "Only one review for reading and meaning with Anki mode enabled",
                                                        on: Settings.ankiModeCombineReadingMeaning,
                                                        target: self,
                                                        action: #selector(ankiModeCombineReadingMeaningSwitchChanged(_:)))

    ankiModeCombineReadingMeaning.numberOfSubtitleLines = 0
    ankiModeCombineReadingMeaningIndexPath = model.add(ankiModeCombineReadingMeaning,
                                                       hidden:!Settings.ankiMode)

    model.add(section: "Audio")
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Play audio automatically",
                              subtitle: "When you answer correctly",
                              on: Settings.playAudioAutomatically,
                              target: self,
                              action: #selector(playAudioAutomaticallySwitchChanged(_:))))
    model.add(BasicModelItem(style: .default,
                             title: "Offline audio",
                             subtitle: nil,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapOfflineAudio(_:))))

    model.add(section: "Animations")
    model.add(SwitchModelItem(style: .default,
                              title: "Particle explosion",
                              subtitle: nil,
                              on: Settings.animateParticleExplosion,
                              target: self,
                              action: #selector(animateParticleExplosionSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .default,
                              title: "Level up popup",
                              subtitle: nil,
                              on: Settings.animateLevelUpPopup,
                              target: self,
                              action: #selector(animateLevelUpPopupSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .default,
                              title: "+1",
                              subtitle: nil,
                              on: Settings.animatePlusOne,
                              target: self,
                              action: #selector(animatePlusOneSwitchChanged(_:))))

    self.model = model
    model.reloadTable()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "fonts":
      let vc = segue.destination as! FontsViewController
      vc.setup(services: services)

    case "offlineAudio":
      let vc = segue.destination as! OfflineAudioViewController
      vc.setup(services: services)

    default:
      break
    }
  }

  // MARK: - Text rendering

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

  @objc private func groupMeaningReadingSwitchChanged(_ switchView: UISwitch) {
    Settings.groupMeaningReading = switchView.isOn
    if let groupMeaningReadingIndexPath = groupMeaningReadingIndexPath {
      model?.setIndexPath(groupMeaningReadingIndexPath, hidden: !switchView.isOn)
    }
  }

  @objc private func showAnswerImmediatelySwitchChanged(_ switchView: UISwitch) {
    Settings.showAnswerImmediately = switchView.isOn
  }

  @objc private func showFullAnswerSwitchChanged(_ switchView: UISwitch) {
    Settings.showFullAnswer = switchView.isOn
  }

  @objc private func allowSkippingReviewsSwitchChanged(_ switchView: UISwitch) {
    Settings.allowSkippingReviews = switchView.isOn
  }

  @objc private func minimizeReviewPenaltySwitchChanged(_ switchView: UISwitch) {
    Settings.minimizeReviewPenalty = switchView.isOn
  }

  @objc private func exactMatchSwitchChanged(_ switchView: UISwitch) {
    Settings.exactMatch = switchView.isOn
  }

  @objc private func enableCheatsSwitchChanged(_ switchView: UISwitch) {
    Settings.enableCheats = switchView.isOn
  }

  @objc private func showSRSLevelIndicatorSwitchChanged(_ switchView: UISwitch) {
    Settings.showSRSLevelIndicator = switchView.isOn
  }

  @objc private func showMinutesForNextLevelUpReview(_ switchView: UISwitch) {
    Settings.showMinutesForNextLevelUpReview = switchView.isOn
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

  @objc private func ankiModeSwitchChanged(_ switchView: UISwitch) {
    Settings.ankiMode = switchView.isOn
    Settings.ankiModeCombineReadingMeaning = false
    if let indexPath = ankiModeCombineReadingMeaningIndexPath {
      model?.setIndexPath(indexPath, hidden: !switchView.isOn)
    }
  }

  @objc private func ankiModeCombineReadingMeaningSwitchChanged(_ switchView: UISwitch) {
    Settings.ankiModeCombineReadingMeaning = switchView.isOn
  }

  @objc private func playAudioAutomaticallySwitchChanged(_ switchView: UISwitch) {
    Settings.playAudioAutomatically = switchView.isOn
  }

  // MARK: - Tap handlers

  @objc private func didTapReviewBatchSize(_: BasicModelItem) {
    navigationController?.pushViewController(makeReviewBatchSizeViewController(), animated: true)
  }

  @objc private func fontSizeChanged(_: BasicModelItem) {
    navigationController?.pushViewController(makeFontSizeViewController(), animated: true)
  }

  @objc private func didTapReviewOrder(_: BasicModelItem) {
    navigationController?.pushViewController(makeReviewOrderViewController(), animated: true)
  }

  @objc private func didTapFonts(_: BasicModelItem) {
    performSegue(withIdentifier: "fonts", sender: self)
  }

  @objc private func didTapTaskOrder(_: BasicModelItem) {
    navigationController?.pushViewController(makeTaskOrderViewController(), animated: true)
  }

  @objc private func didTapOfflineAudio(_: Any?) {
    performSegue(withIdentifier: "offlineAudio", sender: self)
  }
}

func makeFontSizeViewController() -> UIViewController {
  let vc = SettingChoiceListViewController(setting: Settings.$fontSize, title: "Font Size")
  for size in stride(from: 1.0, through: 2.5, by: 0.25) {
    let percent = Int((size * 100).rounded())
    vc.addChoice(name: "\(percent)%", value: Float(size))
  }
  return vc
}

func makeReviewBatchSizeViewController() -> UIViewController {
  let vc = SettingChoiceListViewController(setting: Settings.$reviewBatchSize,
                                           title: "Review Batch Size",
                                           helpText: "Set the review queue size.")
  vc.addChoicesFromRange(3 ... 10, suffix: " reviews")
  return vc
}

func makeReviewOrderViewController() -> UIViewController {
  let vc = SettingChoiceListViewController(setting: Settings.$reviewOrder, title: "Review Order")
  vc.addChoicesFromEnum()
  return vc
}

func makeTaskOrderViewController() -> UIViewController {
  let vc = SettingChoiceListViewController(setting: Settings.$meaningFirst,
                                           title: "Back-to-back Order")
  vc.addChoices([
    "Meaning then Reading": true,
    "Reading then Meaning": false,
  ])
  return vc
}
