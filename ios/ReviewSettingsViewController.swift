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
                             accessoryType: .disclosureIndicator) { [unowned self] in self
        .didTapReviewOrder()
      })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Back-to-back",
                              subtitle: "Group Meaning and Reading together",
                              on: Settings
                                .groupMeaningReading) { [unowned self] in
        groupMeaningReadingSwitchChanged($0)
      })
    groupMeaningReadingIndexPath = model.add(BasicModelItem(style: .value1,
                                                            title: "Back-to-back order",
                                                            subtitle: taskOrderValueText,
                                                            accessoryType: .disclosureIndicator) { [
                                               unowned self
                                             ] in
                                               self.didTapTaskOrder()
                                             },
                                             hidden:!Settings
                                               .groupMeaningReading)
    model.add(BasicModelItem(style: .value1,
                             title: "Batch size",
                             subtitle: "\(Settings.reviewBatchSize.description)",
                             accessoryType: .disclosureIndicator) { [unowned self] in self
        .didTapReviewBatchSize()
      })

    model.add(section: "Display")
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show SRS level indicator",
                              subtitle: nil,
                              on: Settings
                                .showSRSLevelIndicator) { [unowned self] in
        showSRSLevelIndicatorSwitchChanged($0)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Fonts",
                             subtitle: nil,
                             accessoryType: .disclosureIndicator) { [unowned self] in self
        .didTapFonts()
      })
    model.add(BasicModelItem(style: .value1,
                             title: "Font size",
                             subtitle: fontSizeValueText,
                             accessoryType: .disclosureIndicator) { [unowned self] in self
        .fontSizeChanged()
      })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show minutes for next level-up review",
                              subtitle: nil,
                              on: Settings
                                .showMinutesForNextLevelUpReview) { [unowned self] in
        showMinutesForNextLevelUpReview($0)
      })

    model.add(section: "Answers & marking")
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Switch to Japanese keyboard",
                              subtitle: "Automatically switch to a Japanese keyboard to type reading answers",
                              on: Settings
                                .autoSwitchKeyboard) { [unowned self] in
        autoSwitchKeyboardSwitchChanged($0)
      })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Reveal answer automatically",
                              subtitle: nil,
                              on: Settings
                                .showAnswerImmediately) { [unowned self] in
        showAnswerImmediatelySwitchChanged($0)
      })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Reveal full answer",
                              subtitle: "Instead of hiding behind a 'Show more information' button",
                              on: Settings
                                .showFullAnswer) { [unowned self] in showFullAnswerSwitchChanged($0)
      })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Exact match",
                              subtitle: "Requires typing in answers exactly correct",
                              on: Settings
                                .exactMatch) { [unowned self] in exactMatchSwitchChanged($0) })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Allow cheating",
                              subtitle: "Ignore Typos and Add Synonym",
                              on: Settings
                                .enableCheats) { [unowned self] in enableCheatsSwitchChanged($0) })
    model.add(SwitchModelItem(style: .default,
                              title: "Allow skipping",
                              subtitle: nil,
                              on: Settings
                                .allowSkippingReviews) { [unowned self] in
        allowSkippingReviewsSwitchChanged($0)
      })

    model.add(SwitchModelItem(style: .subtitle,
                              title: "Minimize review penalty",
                              subtitle:
                              "Treat reviews answered incorrect multiple times as if answered incorrect once",
                              on: Settings
                                .minimizeReviewPenalty) { [unowned self] in
        minimizeReviewPenaltySwitchChanged($0)
      })
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Anki mode",
                              subtitle: "Do reviews without typing answers",
                              on: Settings.ankiMode) { [unowned self] in ankiModeSwitchChanged($0)
      })

    let ankiModeCombineReadingMeaning = SwitchModelItem(style: .subtitle,
                                                        title: "Combine Reading + Meaning",
                                                        subtitle: "Only one review for reading and meaning with Anki mode enabled",
                                                        on: Settings
                                                          .ankiModeCombineReadingMeaning) { [
      unowned self
    ] in
      ankiModeCombineReadingMeaningSwitchChanged($0)
    }
    ankiModeCombineReadingMeaningIndexPath = model.add(ankiModeCombineReadingMeaning,
                                                       hidden:!Settings.ankiMode)

    model.add(section: "Audio")
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Play audio automatically",
                              subtitle: "When you answer correctly",
                              on: Settings
                                .playAudioAutomatically) { [unowned self] in
        playAudioAutomaticallySwitchChanged($0)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Offline audio",
                             subtitle: nil,
                             accessoryType: .disclosureIndicator) { [unowned self] in self
        .didTapOfflineAudio()
      })

    model.add(section: "Animations")
    model.add(SwitchModelItem(style: .default,
                              title: "Particle explosion",
                              subtitle: nil,
                              on: Settings
                                .animateParticleExplosion) { [unowned self] in
        animateParticleExplosionSwitchChanged($0)
      })
    model.add(SwitchModelItem(style: .default,
                              title: "Level up popup",
                              subtitle: nil,
                              on: Settings
                                .animateLevelUpPopup) { [unowned self] in
        animateLevelUpPopupSwitchChanged($0)
      })
    model.add(SwitchModelItem(style: .default,
                              title: "+1",
                              subtitle: nil,
                              on: Settings
                                .animatePlusOne) { [unowned self] in animatePlusOneSwitchChanged($0)
      })

    self.model = model
    model.reloadTable()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.ReviewSettings(segue) {
    case .fonts:
      let vc = segue.destination as! FontsViewController
      vc.setup(services: services)

    case .offlineAudio:
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

  private func animateParticleExplosionSwitchChanged(_ switchView: UISwitch) {
    Settings.animateParticleExplosion = switchView.isOn
  }

  private func animateLevelUpPopupSwitchChanged(_ switchView: UISwitch) {
    Settings.animateLevelUpPopup = switchView.isOn
  }

  private func animatePlusOneSwitchChanged(_ switchView: UISwitch) {
    Settings.animatePlusOne = switchView.isOn
  }

  private func groupMeaningReadingSwitchChanged(_ switchView: UISwitch) {
    Settings.groupMeaningReading = switchView.isOn
    if let groupMeaningReadingIndexPath = groupMeaningReadingIndexPath {
      model?.setIndexPath(groupMeaningReadingIndexPath, hidden: !switchView.isOn)
    }
  }

  private func showAnswerImmediatelySwitchChanged(_ switchView: UISwitch) {
    Settings.showAnswerImmediately = switchView.isOn
  }

  private func showFullAnswerSwitchChanged(_ switchView: UISwitch) {
    Settings.showFullAnswer = switchView.isOn
  }

  private func allowSkippingReviewsSwitchChanged(_ switchView: UISwitch) {
    Settings.allowSkippingReviews = switchView.isOn
  }

  private func minimizeReviewPenaltySwitchChanged(_ switchView: UISwitch) {
    Settings.minimizeReviewPenalty = switchView.isOn
  }

  private func exactMatchSwitchChanged(_ switchView: UISwitch) {
    Settings.exactMatch = switchView.isOn
  }

  private func enableCheatsSwitchChanged(_ switchView: UISwitch) {
    Settings.enableCheats = switchView.isOn
  }

  private func showSRSLevelIndicatorSwitchChanged(_ switchView: UISwitch) {
    Settings.showSRSLevelIndicator = switchView.isOn
  }

  private func showMinutesForNextLevelUpReview(_ switchView: UISwitch) {
    Settings.showMinutesForNextLevelUpReview = switchView.isOn
  }

  private func autoSwitchKeyboardSwitchChanged(_ switchView: UISwitch) {
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

  private func ankiModeSwitchChanged(_ switchView: UISwitch) {
    Settings.ankiMode = switchView.isOn
    Settings.ankiModeCombineReadingMeaning = false
    if let indexPath = ankiModeCombineReadingMeaningIndexPath {
      model?.setIndexPath(indexPath, hidden: !switchView.isOn)
    }
  }

  private func ankiModeCombineReadingMeaningSwitchChanged(_ switchView: UISwitch) {
    Settings.ankiModeCombineReadingMeaning = switchView.isOn
  }

  private func playAudioAutomaticallySwitchChanged(_ switchView: UISwitch) {
    Settings.playAudioAutomatically = switchView.isOn
  }

  // MARK: - Tap handlers

  private func didTapReviewBatchSize() {
    navigationController?.pushViewController(makeReviewBatchSizeViewController(), animated: true)
  }

  private func fontSizeChanged() {
    navigationController?.pushViewController(makeFontSizeViewController(), animated: true)
  }

  private func didTapReviewOrder() {
    navigationController?.pushViewController(makeReviewOrderViewController(), animated: true)
  }

  private func didTapFonts() {
    perform(segue: StoryboardSegue.ReviewSettings.fonts, sender: self)
  }

  private func didTapTaskOrder() {
    navigationController?.pushViewController(makeTaskOrderViewController(), animated: true)
  }

  private func didTapOfflineAudio() {
    perform(segue: StoryboardSegue.ReviewSettings.offlineAudio, sender: self)
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
