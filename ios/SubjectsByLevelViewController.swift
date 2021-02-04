// Copyright 2021 David Sansome
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

@objc
class SubjectsByLevelViewController: UITableViewController, SubjectDelegate {
  private var services: TKMServices!
  private var level: Int!
  private var showAnswers: Bool!
  private var model: TKMTableModel?

  @objc func setup(services: TKMServices, level: Int, showAnswers: Bool) {
    self.services = services
    self.level = level
    setShowAnswers(showAnswers, animated: false)
  }

  // Only for objective-c compatibility.
  @objc func getLevel() -> Int {
    level
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Level \(level!)"

    let model = TKMMutableTableModel(tableView: tableView)
    model.addSection("Radicals")
    model.addSection("Kanji")
    model.addSection("Vocabulary")

    for assignment in services.localCachingClient.getAssignments(level: level) {
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }

      let section = subject.subjectType.rawValue - 1
      let item = SubjectModelItem(subject: subject, delegate: self, assignment: assignment,
                                  readingWrong: false, meaningWrong: false)
      item.showLevelNumber = false
      item.showAnswers = showAnswers
      if assignment.isLocked || assignment.isBurned {
        item.gradientColors = TKMStyle.lockedGradient
      }
      model.add(item, toSection: Int32(section))
    }

    let comparator = { (a: Any, b: Any) -> ComparisonResult in
      guard let a = a as? SubjectModelItem,
        let b = b as? SubjectModelItem,
        let aAssignment = a.assignment,
        let bAssignment = b.assignment else {
        return .orderedSame
      }

      if aAssignment.isLocked, !bAssignment.isLocked { return .orderedDescending }
      if !aAssignment.isLocked, bAssignment.isLocked { return .orderedAscending }
      if aAssignment.isReviewStage, !bAssignment.isReviewStage { return .orderedAscending }
      if !aAssignment.isReviewStage, bAssignment.isReviewStage { return .orderedDescending }
      if aAssignment.isLessonStage, !bAssignment.isLessonStage { return .orderedAscending }
      if !aAssignment.isLessonStage, bAssignment.isLessonStage { return .orderedDescending }
      if aAssignment.srsStage < bAssignment.srsStage { return .orderedAscending }
      if aAssignment.srsStage > bAssignment.srsStage { return .orderedDescending }
      return .orderedSame
    }

    model.sortSection(0, usingComparator: comparator)
    model.sortSection(1, usingComparator: comparator)
    model.sortSection(2, usingComparator: comparator)

    for section in 0 ..< model.sectionCount {
      var lastAssignment: TKMAssignment?

      var itemIndex = 0
      while itemIndex < model.items(inSection: section).count {
        let item = model.items(inSection: section)[itemIndex]
        if let assignment = (item as! SubjectModelItem).assignment {
          if lastAssignment == nil || lastAssignment!.srsStage != assignment.srsStage ||
            lastAssignment!.isReviewStage != assignment.isReviewStage ||
            lastAssignment!.isLessonStage != assignment.isLessonStage {
            var label = ""
            if assignment.isLocked {
              label = "Locked"
            } else if assignment.isLessonStage {
              label = "Available in Lessons"
            } else {
              label = assignment.srsStage.description
            }
            model.insert(TKMListSeparatorItem(label: label), at: Int32(itemIndex),
                         inSection: section)
            itemIndex += 1
          }
          lastAssignment = assignment
        }
        itemIndex += 1
      }
    }

    self.model = model
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  @objc
  func setShowAnswers(_ value: Bool, animated: Bool = false) {
    showAnswers = value
    guard let model = model else {
      return
    }

    for section in 0 ..< model.sectionCount {
      for item in model.items(inSection: section) {
        if let item = item as? SubjectModelItem {
          item.showAnswers = showAnswers
        }
      }
    }

    for cell in tableView.visibleCells {
      if let cell = cell as? SubjectModelView {
        cell.setShowAnswers(showAnswers, animated: animated)
      }
    }
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let vc = storyboard!
      .instantiateViewController(withIdentifier: "subjectDetailsViewController") as! SubjectDetailsViewController
    vc.setup(services: services, subject: subject)
    navigationController?.pushViewController(vc, animated: true)
  }
}
