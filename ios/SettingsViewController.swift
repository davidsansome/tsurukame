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

class SettingsViewController: UITableViewController, TKMViewController {
  private var services: TKMServices!
  private var model: TableModel?
  private var versionIndexPath: IndexPath?
  private var notificationHandler: ((Bool) -> Void)?

  func setup(services: TKMServices) {
    self.services = services
  }

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
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "Settings")
    model.add(BasicModelItem(style: .default,
                             title: "Appearance & Notifications",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.performSegue(withIdentifier: "appSettings", sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Lessons",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.performSegue(withIdentifier: "lessonSettings", sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Reviews",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.performSegue(withIdentifier: "reviewSettings", sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Radicals, Kanji & Vocabulary",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.performSegue(withIdentifier: "subjectDetailsSettings", sender: self)
      })

    model.add(section: "Diagnostics")
    if let coreVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
      let version = "\(coreVersion).\(build)"
      versionIndexPath = model
        .add(BasicModelItem(style: .value1, title: "Version", subtitle: version,
                            accessoryType: .none))
    }
    let exportLocalDatabaseItem = BasicModelItem(style: .subtitle,
                                                 title: "Export local database",
                                                 subtitle: "To attach to bug reports or email to the developer",
                                                 accessoryType: .disclosureIndicator,
                                                 target: self,
                                                 action: #selector(didTapSendBugReport(_:)))
    exportLocalDatabaseItem.numberOfSubtitleLines = 0
    model.add(exportLocalDatabaseItem)

    model.addSection()
    let logOutItem = BasicModelItem(style: .default,
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

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "reviewSettings":
      let vc = segue.destination as! ReviewSettingsViewController
      vc.setup(services: services)

    default:
      break
    }
  }

  // MARK: - UITableViewController

  override func tableView(_: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
    indexPath == versionIndexPath
  }

  override func tableView(_: UITableView, canPerformAction action: Selector, forRowAt _: IndexPath,
                          withSender _: Any?) -> Bool {
    action == #selector(copy(_:))
  }

  override func tableView(_ tableView: UITableView, performAction action: Selector,
                          forRowAt indexPath: IndexPath, withSender _: Any?) {
    if action == #selector(copy(_:)) {
      let cell = tableView.cellForRow(at: indexPath)
      UIPasteboard.general.string = cell?.detailTextLabel?.text
    }
  }

  // MARK: - Tap handlers

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
