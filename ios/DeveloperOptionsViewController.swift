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
import WaniKaniAPI

class DeveloperOptionsViewController: SettingsTableViewController, TKMViewController {
  private let services: TKMServices
  private var model: TableModel?

  init(services: TKMServices) {
    self.services = services
    if #available(iOS 13.0, *) {
      super.init(style: .insetGrouped)
    } else {
      super.init(style: .grouped)
    }
    navigationItem.title = "Developer options"
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

    model.add(section: "WaniKani API")
    model.add(BasicModelItem(style: .subtitle,
                             title: "API base URL",
                             subtitle: Settings.apiBaseUrl,
                             accessoryType: .disclosureIndicator) { [unowned self] in
        didTapApiBaseUrl()
      })

    model.add(section: "Diagnostics")
    model.add(BasicModelItem(style: .subtitle,
                             title: "Export local database",
                             subtitle: "To attach to bug reports or email to the developer",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        didTapExportDatabase()
      })
    model.add(BasicModelItem(style: .subtitle,
                             title: "Clear avatar image cache",
                             subtitle: "If your avatar isn't loading, try clearing the image cache.",
                             accessoryType: .none) { [unowned self] in didTapClearImageCache() })

    self.model = model
    styleRows(model)
    model.reloadTable()
  }

  // MARK: - Tap handlers

  private func didTapApiBaseUrl() {
    ApiBaseUrlAlert.present(from: self) { [unowned self] url in
      services.client.baseUrl = url
      rerender()
    }
  }

  private func didTapExportDatabase() {
    let c = UIActivityViewController(activityItems: [LocalCachingClient.databaseUrl()],
                                     applicationActivities: nil)
    present(c, animated: true, completion: nil)
  }

  private func didTapClearImageCache() {
    HNKCache.shared().removeAllImages()
    let c = UIAlertController(title: "Image cache cleared", message: nil, preferredStyle: .alert)
    c.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(c, animated: true, completion: nil)
  }
}
