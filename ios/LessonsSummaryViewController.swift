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

@objc class LessonsSummaryViewController: UITableViewController, TKMSubjectDelegate,
  ReviewViewControllerDelegate {
  var tableModel: TKMMutableTableModel?
  var services: TKMServices?
  var items: [ReviewItem]?

  @objc public func setup(withServices services: TKMServices, items: [ReviewItem]) {
    self.services = services
    self.items = items
  }

  override func viewDidLoad() {
    refreshModel()
  }

  func refreshModel() {
    tableModel = TKMMutableTableModel(tableView: tableView)

    tableModel?.addSection("New Items")
    for item in items ?? [] {
      if let subject = services?.dataLoader.load(subjectID: Int(item.assignment.subjectId)) {
        tableModel?.add(TKMSubjectModelItem(subject: subject, delegate: self))
      }
    }

    let doneButton = UIButton(type: .system)
    doneButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
    doneButton.setTitle("Done", for: .normal)
    doneButton.addTarget(self, action: #selector(didTapDoneButton), for: .touchUpInside)

    let moreButton = UIButton(type: .system)
    moreButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)

    let lessonCount = Int(services?.localCachingClient.availableLessonCount ?? 0)
    let nextGroupCount = min(lessonCount, Int(Settings.lessonBatchSize))
    if nextGroupCount > 0 {
      moreButton.setTitle("Next \(nextGroupCount)", for: .normal)
      moreButton.addTarget(self, action: #selector(didTapMoreButton), for: .touchUpInside)
    } else {
      // No more lessons.
      moreButton.setTitle("More", for: .normal)
      moreButton.isEnabled = false
    }

    tableModel?.add(ActionModelItem(leftButton: doneButton, rightButton: moreButton))
  }

  @IBAction func didTapDoneButton() {
    navigationController?.popToRootViewController(animated: true)
  }

  @IBAction func didTapMoreButton() {
    guard let services = services else { return }

    let assignments = services.localCachingClient.getAllAssignments()
    // TODO: Relaunch into lessons
    var items = ReviewItem.assignmentsReady(forLesson: assignments,
                                            dataLoader: services.dataLoader)

    if items.count == 0 {
      return
    }

    items = items.sorted(by: { a, b in a.compare(forLessons: b) })
    if items.count > Settings.lessonBatchSize {
      // items = Array(items[0 ..< Int(Settings.lessonBatchSize)])
      items = Array([items[0]])
    }

    if let vc = storyboard?
      .instantiateViewController(withIdentifier: "reviewViewController") as? ReviewViewController {
      vc
        .setup(withServices: services, items: items, showMenuButton: false,
               showSubjectHistory: false, delegate: self)
      navigationController?.pushViewController(vc, animated: true)
    }
  }

  // MARK: - TKMSubjectDelegate

  func didTap(_: TKMSubject!) {
    // Ignore taps
  }

  // MARK: - ReviewViewControllerDelegate

  func reviewViewControllerAllowsCheats(forReviewItem _: ReviewItem) -> Bool {
    false
  }

  func reviewViewControllerAllowsCustomFonts() -> Bool {
    false
  }

  func reviewViewControllerShowsSuccessRate() -> Bool {
    false
  }

  func reviewViewControllerFinishedAllReviewItems(_: ReviewViewController) {
    navigationController?.popToRootViewController(animated: true)
  }
}
