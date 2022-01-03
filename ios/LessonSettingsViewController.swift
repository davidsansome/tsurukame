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

class LessonSettingsViewController: UITableViewController, TKMViewController {
  private var model: TableModel?

  // MARK: - TKMViewController

  func canSwipeToGoBack() -> Bool {
    true
  }

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

  // MARK: - Tap handlers

  @objc private func didTapLessonOrder(_: BasicModelItem) {
    performSegue(withIdentifier: "lessonOrder", sender: self)
  }

  @objc private func didTapLessonBatchSize(_: BasicModelItem) {
    performSegue(withIdentifier: "lessonBatchSize", sender: self)
  }

  @objc private func didTapApprenticeLessonsLimit(_: BasicModelItem) {
    performSegue(withIdentifier: "apprenticeLessonsLimit", sender: self)
  }
}
