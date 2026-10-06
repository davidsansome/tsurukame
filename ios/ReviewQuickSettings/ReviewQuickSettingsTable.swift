// Copyright 2025 David Sansome
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

class ReviewQuickSettingsTable: UIViewController, UITableViewDelegate {
  weak var delegate: ReviewQuickSettingsMenuDelegate?
  var services: TKMServices
  var model: TableModel!

  var tableView: UITableView!

  init(services: TKMServices, delegate: ReviewQuickSettingsMenuDelegate?) {
    self.services = services
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    tableView = UITableView(frame: .zero, style: .grouped)
    tableView.delegate = self
    // The menu slides in like a night sky beside the review.
    tableView.backgroundColor = TKMStyle.Color.night
    tableView.separatorColor = UIColor.white.withAlphaComponent(0.12)
    view = tableView
  }

  func rerender() {}

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    rerender()
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView,
                 forSection section: Int) {
    if let header = view as? UITableViewHeaderFooterView,
       let title = tableView.dataSource?.tableView?(tableView, titleForHeaderInSection: section) {
      var config = header.defaultContentConfiguration()
      config.attributedText = NSAttributedString(string: title.uppercased(), attributes: [
        .font: UIFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: TKMStyle.Color.onNightSecondary,
        .kern: 1.6,
      ])
      header.contentConfiguration = config
    }
  }

  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell,
                 forRowAt _: IndexPath) {
    cell.backgroundColor = tableView.backgroundColor
    cell.textLabel?.textColor = TKMStyle.Color.onNight
    cell.imageView?.tintColor = TKMStyle.Color.onNight
    cell.tintColor = TKMStyle.Color.onNight
    cell.separatorInset = .zero

    // Disclosure indicators don't take the cell's tint color, so we have to change the button's
    // image manually.
    if cell.accessoryType == .disclosureIndicator {
      // Find the button in the cell.
      if let button = cell.subviews.first(where: {
        $0.isKind(of: UIButton.self)
      }) as? UIButton {
        if let image = button.backgroundImage(for: .normal) {
          button.setBackgroundImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
          button.tintColor = TKMStyle.Color.onNight
        }
      }
    }
  }
}
