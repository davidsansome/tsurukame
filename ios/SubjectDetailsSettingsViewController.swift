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

class SubjectDetailsSettingsViewController: UITableViewController, TKMViewController {
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

    let katakanaItem = SwitchModelItem(style: .subtitle,
                                       title: "Use Katakana for Onyomi",
                                       subtitle: "Show Onyomi kanji readings in Katakana instead of Hiragana",
                                       on: Settings.useKatakanaForOnyomi,
                                       target: self,
                                       action: #selector(useKatakanaForOnyomiSwitchChanged(_:)))
    katakanaItem.numberOfSubtitleLines = 0
    model.add(katakanaItem)
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show all kanji readings",
                              subtitle: "Primary reading(s) will be shown in bold",
                              on: Settings.showAllReadings,
                              target: self,
                              action: #selector(showAllReadingsSwitchChanged(_:))))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show stats section",
                              subtitle: "Level, SRS stage, and more",
                              on: Settings.showStatsSection,
                              target: self,
                              action: #selector(showStatsSectionChanged(_:))))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show old mnemonics",
                              subtitle: "Include radical mnemonics removed in 2018",
                              on: Settings.showOldMnemonic,
                              target: self,
                              action: #selector(showOldMnemonicSwitchChanged(_:))))

    self.model = model
    model.reloadTable()
  }

  // MARK: - Switch change handlers

  @objc private func showStatsSectionChanged(_ switchView: UISwitch) {
    Settings.showStatsSection = switchView.isOn
  }

  @objc private func showOldMnemonicSwitchChanged(_ switchView: UISwitch) {
    Settings.showOldMnemonic = switchView.isOn
  }

  @objc private func useKatakanaForOnyomiSwitchChanged(_ switchView: UISwitch) {
    Settings.useKatakanaForOnyomi = switchView.isOn
  }

  @objc private func showAllReadingsSwitchChanged(_ switchView: UISwitch) {
    Settings.showAllReadings = switchView.isOn
  }
}
