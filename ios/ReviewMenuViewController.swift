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

@objc(TKMReviewMenuDelegate)
protocol ReviewMenuDelegate: AnyObject {
  func endReviewSession(button: UIView)
  func wrapUp()
  func wrapUpCount() -> Int
}

@objc(TKMReviewMenuViewController)
@objcMembers
class ReviewMenuViewController: UIViewController, UITableViewDelegate {
  weak var delegate: ReviewMenuDelegate?
  private var model: TableModel!

  private var endItem: BasicModelItem?

  @IBOutlet private var tableView: UITableView!

  private func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: self)

    model.add(section: "Quick settings")
    model.add(CheckmarkModelItem(style: .default, title: "Allow cheating",
                                 on: Settings.enableCheats) { on in
        Settings.enableCheats = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Autoreveal answers",
                                 on: Settings.showAnswerImmediately) { on in
        Settings.showAnswerImmediately = on
      })
    model.add(CheckmarkModelItem(style: .default, title: "Autoplay audio",
                                 on: Settings.playAudioAutomatically) { on in
        Settings.playAudioAutomatically = on
      })

    model.add(section: "End review session")
    endItem = BasicModelItem(style: .default, title: "End review session",
                             accessoryType: .disclosureIndicator) { [weak self] in self?
      .endReviewSession()
    }
    endItem!.image = UIImage(named: "baseline_cancel_black_24pt")
    model.add(endItem!)

    var wrapUpText = "Wrap up"
    if let wrapUpCount = delegate?.wrapUpCount(), wrapUpCount != 0 {
      wrapUpText = "Wrap up (\(wrapUpCount) to go)"
    }

    let wrapUp = BasicModelItem(style: .default, title: wrapUpText,
                                accessoryType: .disclosureIndicator) { [weak self] in
      self?.delegate?.wrapUp()
    }
    wrapUp.image = UIImage(named: "baseline_access_time_black_24pt")
    model.add(wrapUp)

    self.model = model
    model.reloadTable()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    rerender()
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
  }
}
