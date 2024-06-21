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

protocol ReviewMenuDelegate: AnyObject {
  func quickSettingsChanged(closeDrawer: Bool)
  func endReviewSession(button: UIView)
  func wrapUp()
  func wrapUpCount() -> Int
}

class ReviewMenuViewController: UIViewController, UITableViewDelegate {
  private weak var delegate: ReviewMenuDelegate?
  private var services: TKMServices!
  private var model: TableModel!

  private var endItem: BasicModelItem?

  // Set to true when another settings view controller is pushed. Upon returning to
  // this view controller, the ReviewViewController will reload its display.
  private var isInSettingsVc = false

  @IBOutlet private var tableView: UITableView!

  func setup(services: TKMServices, delegate: ReviewMenuDelegate) {
    self.services = services
    self.delegate = delegate
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "Display")
    model.add(BasicModelItem(style: .default, title: "Dark/light mode",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [weak self] in
        self?.navigationController?.pushViewController(makeInterfaceStyleViewController(),
                                                       animated: true)
        self?.isInSettingsVc = true
      })
    model.add(CheckmarkModelItem(style: .default, title: "Show SRS level indicator",
                                 on: Settings.showSRSLevelIndicator) {
        [weak self] on in
        Settings.showSRSLevelIndicator = on
        self?.delegate?.quickSettingsChanged(closeDrawer: false)
      })
    model.add(BasicModelItem(style: .default, title: "Fonts",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [weak self] in
        self?.performSegue(withIdentifier: "fonts", sender: self)
      })
    model.add(BasicModelItem(style: .default, title: "Font size",
                             subtitle: nil, accessoryType: .disclosureIndicator) {
        [weak self] in
        self?.navigationController?.pushViewController(makeFontSizeViewController(), animated: true)
        self?.isInSettingsVc = true
      })

    model.add(section: "Answers & Marking")
    model.add(CheckmarkModelItem(style: .default, title: "Autoreveal answers",
                                 on: Settings.showAnswerImmediately) { on in
        Settings.showAnswerImmediately = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Reveal full answer",
                                 on: Settings.showFullAnswer) { on in
        Settings.showFullAnswer = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Exact match",
                                 on: Settings.exactMatch) { on in
        Settings.exactMatch = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Allow cheating",
                                 on: Settings.enableCheats) { on in
        Settings.enableCheats = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Allow skipping",
                                 on: Settings.allowSkippingReviews) { [weak self] on in
        Settings.allowSkippingReviews = on
        self?.delegate?.quickSettingsChanged(closeDrawer: false)
      })

    model.add(section: "Audio")
    model.add(CheckmarkModelItem(style: .default, title: "Autoplay audio",
                                 on: Settings.playAudioAutomatically) { on in
        Settings.playAudioAutomatically = on
      })

    model.add(section: "End review session")
    endItem = BasicModelItem(style: .default, title: "End review session") { [weak self] in self?
      .endReviewSession()
    }
    endItem!.image = UIImage(named: "baseline_cancel_black_24pt")
    model.add(endItem!)

    var wrapUpText = "Wrap up"
    if let wrapUpCount = delegate?.wrapUpCount(), wrapUpCount != 0 {
      wrapUpText = "Wrap up (\(wrapUpCount) to go)"
    }

    let wrapUp = BasicModelItem(style: .default, title: wrapUpText) { [weak self] in
      self?.delegate?.wrapUp()
    }
    wrapUp.image = UIImage(named: "baseline_access_time_black_24pt")
    model.add(wrapUp)

    self.model = model
    model.reloadTable()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "fonts":
      let vc = segue.destination as! FontsViewController
      vc.setup(services: services)
      isInSettingsVc = true

    default:
      break
    }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    rerender()

    if isInSettingsVc {
      isInSettingsVc = false
      delegate?.quickSettingsChanged(closeDrawer: true)
    }
  }

  private func endReviewSession() {
    if let endItem = endItem, let cell = endItem.cell, let delegate = delegate {
      delegate.endReviewSession(button: cell)
    }
  }

  // MARK: - UITableViewDelegate

  func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
    if let header = view as? UITableViewHeaderFooterView {
      header.textLabel?.textColor = .lightGray
    }
  }

  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell,
                 forRowAt _: IndexPath) {
    cell.backgroundColor = tableView.backgroundColor
    cell.textLabel?.textColor = .white
    cell.imageView?.tintColor = .white
    cell.tintColor = .white
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
          button.tintColor = .white
        }
      }
    }
  }
}
