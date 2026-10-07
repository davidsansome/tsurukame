// Copyright 2026 David Sansome
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

class SettingsViewController: SettingsTableViewController, TKMViewController {
  private var services: TKMServices!
  private var model: TableModel?
  private var versionIndexPath: IndexPath?
  private var notificationHandler: ((Bool) -> Void)?

  func setup(services: TKMServices) {
    self.services = services
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
    let model = MutableTableModel(tableView: tableView, delegate: self)

    if let user = services.localCachingClient.getUserInfo() {
      model.addSection()
      model.add(SettingsAccountItem(username: user.username, level: Int(user.level),
                                    imageURL: currentUserProfileImageURL()))
    }

    model.add(section: "Settings")
    model.add(BasicModelItem(style: .default,
                             title: "Appearance & Notifications",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.appSettings, sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Lessons",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.lessonSettings, sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Reviews",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.reviewSettings, sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Radicals, Kanji & Vocabulary",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        self.perform(segue: StoryboardSegue.Settings.subjectDetailsSettings, sender: self)
      })

    model.add(section: "Diagnostics")
    if let coreVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
      let version = "\(coreVersion).\(build)"
      versionIndexPath = model
        .add(BasicModelItem(style: .value1, title: "Version", subtitle: version,
                            accessoryType: .none))
    }
    model.add(BasicModelItem(style: .subtitle,
                             title: "Export local database",
                             subtitle: "To attach to bug reports or email to the developer",
                             accessoryType: .disclosureIndicator) { [unowned self] in
        didTapSendBugReport()
      })
    model.add(BasicModelItem(style: .subtitle,
                             title: "Clear avatar image cache",
                             subtitle: "If your avatar isn't loading, try clearing the image cache.",
                             accessoryType: .none) { [unowned self] in didTapClearImageCache() })

    model.addSection()
    let logOutItem = BasicModelItem(style: .default,
                                    title: "Log out",
                                    subtitle: nil,
                                    accessoryType: .none) { [unowned self] in didTapLogOut() }
    logOutItem.textColor = TKMStyle.Color.accent
    model.add(logOutItem)

    self.model = model
    styleRows(model)
    model.reloadTable()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.Settings(segue) {
    case .reviewSettings:
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

  private func didTapLogOut() {
    let c = UIAlertController(title: "Are you sure?", message: nil, preferredStyle: .alert)
    c.addAction(UIAlertAction(title: "Log out", style: .destructive, handler: { _ in
      NotificationCenter.default.post(name: .logout, object: self)
    }))
    c.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(c, animated: true, completion: nil)
  }

  private func didTapSendBugReport() {
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

// The user's avatar, name and level, at the top of the settings.
private class SettingsAccountItem: TableModelItem {
  let username: String
  let level: Int
  let imageURL: URL

  init(username: String, level: Int, imageURL: URL) {
    self.username = username
    self.level = level
    self.imageURL = imageURL
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: SettingsAccountCell.self)
  }
}

private class SettingsAccountCell: TableModelCell {
  @TypedModelItem var item: SettingsAccountItem

  // Haneke needs a size to pick its cache format before the first layout.
  private let avatar = UIImageView(frame: CGRect(x: 0, y: 0, width: 52, height: 52))
  private let nameLabel = UILabel()
  private let detailLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    avatar.backgroundColor = TKMStyle.Color.grey80
    avatar.contentMode = .scaleAspectFill
    avatar.layer.cornerRadius = 26
    avatar.clipsToBounds = true

    nameLabel.font = UIFontMetrics(forTextStyle: .headline)
      .scaledFont(for: UIFont.systemFont(ofSize: 18, weight: .black))
    nameLabel.textColor = TKMStyle.Color.label
    detailLabel.font = UIFontMetrics(forTextStyle: .subheadline)
      .scaledFont(for: UIFont.systemFont(ofSize: 13))
    detailLabel.textColor = TKMStyle.Color.grey33
    for label in [nameLabel, detailLabel] {
      label.adjustsFontForContentSizeCategory = true
    }

    let labels = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
    labels.axis = .vertical
    labels.spacing = 2
    let row = UIStackView(arrangedSubviews: [avatar, labels])
    row.alignment = .center
    row.spacing = 14
    row.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(row)

    NSLayoutConstraint.activate([
      avatar.widthAnchor.constraint(equalToConstant: 52),
      avatar.heightAnchor.constraint(equalToConstant: 52),
      row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
      row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
      row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    nameLabel.text = item.username
    detailLabel.text = "Level \(item.level) · WaniKani"
    avatar.hnk_setImage(from: item.imageURL)
  }
}
