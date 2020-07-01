// Copyright 2020 David Sansome
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

import UIKit

@objcMembers class ReviewMenuViewController: UIViewController, UITableViewDelegate {
  var tableView: UITableView!
  var rightConstraint: NSLayoutConstraint!
  var model: TKMTableModel!
  let disclosureIndicator = UITableViewCell.AccessoryType.disclosureIndicator

  weak var delegate: ReviewMenuDelegate!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  func rerender() {
    let model: TKMMutableTableModel = TKMMutableTableModel(tableView: tableView, delegate: self)
    model.addSection("Quick Settings")
    model.add(TKMCheckmarkModelItem(style: .default, title: "Ignore & Add Synonym",
                                    subtitle: nil, on: Settings.enableCheats, target: self,
                                    action: #selector(enableCheatsChanged(item:))))
    model.add(TKMCheckmarkModelItem(style: .default, title: "Autoreveal answers",
                                    subtitle: nil, on: Settings.showAnswerImmediately, target: self,
                                    action: #selector(showAnswerImmediatelyChanged(item:))))
    model.add(TKMCheckmarkModelItem(style: .default, title: "Autoplay audio",
                                    subtitle: nil, on: Settings.playAudioAutomatically,
                                    target: self,
                                    action: #selector(playAudioAutomaticallyChanged(item:))))
    model.add(TKMBasicModelItem(style: .default, title: "Review order", subtitle: nil,
                                accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapReviewOrder(item:))))
    model.add(TKMBasicModelItem(style: .default, title: "Review item type order",
                                subtitle: nil, accessoryType: disclosureIndicator, target: self,
                                action: #selector(didTapReviewItemOrder(item:))))
    model.addSection("End Review Session")
    let endReviewSession = TKMBasicModelItem(style: .default, title: "End review session",
                                             subtitle: nil, accessoryType: disclosureIndicator,
                                             target: self, action: #selector(endSession(item:)))
    endReviewSession.image = UIImage(named: "baseline_cancel_black_24pt")!
    model.add(endReviewSession)
    let wrapUpText = delegate
      .wrapUpCount() != 0 ? "Wrap up (\(delegate.wrapUpCount()) to go)" : "Wrap up"
    let wrapUp = TKMBasicModelItem(style: .default, title: wrapUpText, subtitle: nil,
                                   accessoryType: disclosureIndicator, target: self,
                                   action: #selector(wrapUp(item:)))
    wrapUp.image = UIImage(named: "baseline_access_time_black_24pt")!
    model.add(wrapUp)

    self.model = model
    tableView.reloadData()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle { UIStatusBarStyle.lightContent }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    rerender()
  }

  // MARK: - UITableViewDelegate

  func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
    let header = view as! UITableViewHeaderFooterView
    header.textLabel?.textColor = UIColor.lightGray
  }

  func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
    cell.backgroundColor = tableView.backgroundColor
    cell.textLabel!.textColor = UIColor.white
    cell.imageView!.tintColor = UIColor.white
    cell.tintColor = UIColor.white
    cell.separatorInset = UIEdgeInsets.zero
  }

  // MARK: - Handlers

  func enableCheatsChanged(item: TKMCheckmarkModelItem) {
    Settings.enableCheats = item.on
  }

  func showAnswerImmediatelyChanged(item: TKMCheckmarkModelItem) {
    Settings.showAnswerImmediately = item.on
  }

  func playAudioAutomaticallyChanged(item: TKMCheckmarkModelItem) {
    Settings.playAudioAutomatically = item.on
  }

  func didTapReviewOrder(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewOrder", sender: self)
  }

  func didTapReviewItemOrder(item _: TKMBasicModelItem) {
    performSegue(withIdentifier: "reviewItemOrder", sender: self)
  }

  func endSession(item: TKMBasicModelItem) {
    delegate.didTapEndReviewSession(button: item.cell!)
  }

  func wrapUp(item _: TKMBasicModelItem) {
    delegate.didTapWrapUp()
  }
}
