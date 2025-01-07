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

class SubjectDetailsSettingsViewController: UITableViewController, TKMViewController {
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

    model.add(SwitchModelItem(style: .subtitle,
                              title: "Use Katakana for Onyomi",
                              subtitle: "Show Onyomi kanji readings in Katakana instead of Hiragana",
                              on: Settings.useKatakanaForOnyomi,
                              switchHandler: useKatakanaForOnyomiSwitchChanged))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show all kanji readings",
                              subtitle: "Primary reading(s) will be shown in bold",
                              on: Settings.showAllReadings,
                              switchHandler: showAllReadingsSwitchChanged))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show stats section",
                              subtitle: "Level, SRS stage, and more",
                              on: Settings.showStatsSection,
                              switchHandler: showStatsSectionChanged))
    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show old mnemonics",
                              subtitle: "Include radical mnemonics removed in 2018",
                              on: Settings.showOldMnemonic,
                              switchHandler: showOldMnemonicSwitchChanged))
    if #available(iOS 15.0, *) {
      model.add(SwitchModelItem(style: .subtitle,
                                title: "Show Artwork by @AmandaBear",
                                subtitle: "Mnemonic Artwork for Radical Levels 1-10 and Kanji Levels 1-7",
                                on: Settings.showArtwork,
                                switchHandler: showArtworkChanged))
    }

    model.add(SwitchModelItem(style: .subtitle,
                              title: "Show prior level graph until fully completed",
                              subtitle: "When you finish the kanji for a given level, keep showing that level's completion graph until all radicals, kanji, and vocabulary have gotten to Guru or higher",
                              on: Settings.showPreviousLevelGraph,
                              switchHandler: levelGraphSwitchChanged))

    self.model = model
    model.reloadTable()
  }

  // MARK: - Switch change handlers

  private func showStatsSectionChanged(_ switchView: UISwitch) {
    Settings.showStatsSection = switchView.isOn
  }

  private func showArtworkChanged(_ switchView: UISwitch) {
    Settings.showArtwork = switchView.isOn
  }

  private func showOldMnemonicSwitchChanged(_ switchView: UISwitch) {
    Settings.showOldMnemonic = switchView.isOn
  }

  private func useKatakanaForOnyomiSwitchChanged(_ switchView: UISwitch) {
    Settings.useKatakanaForOnyomi = switchView.isOn
  }

  private func showAllReadingsSwitchChanged(_ switchView: UISwitch) {
    Settings.showAllReadings = switchView.isOn
  }

  private func levelGraphSwitchChanged(_ switchView: UISwitch) {
    Settings.showPreviousLevelGraph = switchView.isOn
  }
}
