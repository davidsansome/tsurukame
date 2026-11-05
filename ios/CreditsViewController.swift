// Copyright David Sansome
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

/** Credits the third-party data the app includes. */
class CreditsViewController: SettingsTableViewController, TKMViewController {
  private struct Credit {
    let title: String
    let description: String
    let url: String
  }

  private static let kCredits = [
    Credit(title: "JMdict",
           description: "Which words are common. JMdict is the property of the Electronic " +
             "Dictionary Research and Development Group, and is used in conformance with the " +
             "Group's licence (CC BY-SA 4.0).",
           url: "https://www.edrdg.org/edrdg/licence.html"),
    Credit(title: "jiten.moe",
           description: "Word frequency rankings, from the jiten.moe global and non-fiction " +
             "frequency lists (CC BY-SA 4.0).",
           url: "https://jiten.moe/frequency-dictionaries"),
    Credit(title: "wordfreq",
           description: "Word frequency rankings, from Robyn Speer's wordfreq (CC BY-SA 4.0).",
           url: "https://github.com/rspeer/wordfreq"),
    Credit(title: "WaniKani Similar Kanji",
           description: "Visually similar kanji, from the databases in mwil's " +
             "WaniKani userscripts.",
           url: "https://github.com/mwil/wanikani-userscripts/tree/master/wanikani-similar-kanji"),
  ]

  private var model: TableModel?

  init() {
    if #available(iOS 13.0, *) {
      super.init(style: .insetGrouped)
    } else {
      super.init(style: .grouped)
    }
    navigationItem.title = "Credits"
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

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

    model.addSection()
    for credit in CreditsViewController.kCredits {
      let item = BasicModelItem(style: .subtitle,
                                title: credit.title,
                                subtitle: credit.description,
                                accessoryType: .disclosureIndicator) {
        if let url = URL(string: credit.url) {
          UIApplication.shared.open(url)
        }
      }
      model.add(item)
    }

    self.model = model
    styleRows(model)
    model.reloadTable()
  }
}
