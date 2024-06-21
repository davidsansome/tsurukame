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

class LessonSettingsViewController: UITableViewController, TKMViewController {
  private var model: TableModel?

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    rerender()
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView)

    model.add(BasicModelItem(style: .value1,
                             title: "Order",
                             subtitle: lessonOrderValueText,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapLessonOrder(_:))))
    model.add(BasicModelItem(style: .value1,
                             title: "Batch size",
                             subtitle: lessonBatchSizeText,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapLessonBatchSize(_:))))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Prioritize current level",
                              subtitle: "Teach items from the current level first",
                              on: Settings.prioritizeCurrentLevel,
                              target: self,
                              action: #selector(prioritizeCurrentLevelChanged(_:))))
    model.add(BasicModelItem(style: .value1,
                             title: "Apprentice limit",
                             subtitle: apprenticeLessonsLimitText,
                             accessoryType: .disclosureIndicator,
                             target: self,
                             action: #selector(didTapApprenticeLessonsLimit(_:))))
    let kanaOnlyVocabSwitch = SwitchModelItem(style: .subtitle,
                                              title: "Show kana-only vocabulary",
                                              subtitle: "Include lessons for kana-only vocabulary" +
                                                " that were added in May 2023",
                                              on: Settings.showKanaOnlyVocab,
                                              target: self,
                                              action: #selector(showKanaOnlyVocabChanged(_:)))
    kanaOnlyVocabSwitch.numberOfSubtitleLines = 0
    model.add(kanaOnlyVocabSwitch)

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

  private var apprenticeLessonsLimitText: String {
    Settings.apprenticeLessonsLimit != Int.max ?
      "\(Settings.apprenticeLessonsLimit)" : "None"
  }

  // MARK: - Switch change handlers

  @objc private func prioritizeCurrentLevelChanged(_ switchView: UISwitch) {
    Settings.prioritizeCurrentLevel = switchView.isOn
  }

  @objc private func showKanaOnlyVocabChanged(_ switchView: UISwitch) {
    Settings.showKanaOnlyVocab = switchView.isOn
  }

  // MARK: - Tap handlers

  @objc private func didTapLessonOrder(_: BasicModelItem) {
    performSegue(withIdentifier: "lessonOrder", sender: self)
  }

  @objc private func didTapLessonBatchSize(_: BasicModelItem) {
    navigationController?.pushViewController(makeLessonBatchSizeViewController(), animated: true)
  }

  @objc private func didTapApprenticeLessonsLimit(_: BasicModelItem) {
    navigationController?.pushViewController(makeApprenticeLessonLimitViewController(),
                                             animated: true)
  }
}

func makeLessonBatchSizeViewController() -> UIViewController {
  let vc = SettingChoiceListViewController(setting: Settings.$lessonBatchSize,
                                           title: "Lesson Batch Size",
                                           helpText: "Set the number of new lessons to be " +
                                             "introduced before the quiz session.")
  vc.addChoicesFromRange(3 ... 10, suffix: " lessons")
  return vc
}

func makeApprenticeLessonLimitViewController() -> UIViewController {
  let vc = SettingChoiceListViewController(setting: Settings.$apprenticeLessonsLimit,
                                           title: "Apprentice Lessons Limit",
                                           helpText: "Stop yourself from starting new lessons " +
                                             "if you have more than this number of " +
                                             "Apprentice-level items already")
  vc.addChoice(name: "No limit", value: Int.max)
  vc.addChoicesFromRange(stride(from: 25, through: 200, by: 25), suffix: "")
  return vc
}
