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

class SubjectsRemainingViewController: UITableViewController, SubjectDelegate {
  var services: TKMServices!
  var model: TKMTableModel?

  func setup(services: TKMServices) {
    self.services = services
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let level = services.localCachingClient.getUserInfo()?.level else {
      return
    }
    navigationItem.title = "Remaining in Level \(level)"

    var radicals = [SubjectModelItem]()
    var kanji = [SubjectModelItem]()
    for assignment in services.localCachingClient.getAssignmentsAtUsersCurrentLevel() {
      if assignment.srsStage > .apprentice4 {
        continue
      }
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }
      if subject.subjectType == .vocabulary {
        continue
      }

      let item = SubjectModelItem(subject: subject, delegate: self, assignment: assignment,
                                  readingWrong: false, meaningWrong: false)
      item.showLevelNumber = false
      item.showAnswers = false
      item.showRemaining = true
      if assignment.isLocked || assignment.isBurned {
        item.gradientColors = TKMStyle.lockedGradient
      }
      switch subject.subjectType {
      case .radical:
        radicals.append(item)
      case .kanji:
        kanji.append(item)
      default:
        break
      }
    }

    let model = TKMMutableTableModel(tableView: tableView)
    if !radicals.isEmpty {
      model.addSection("Radicals")
      for item in radicals {
        model.add(item)
      }
    }
    if !kanji.isEmpty {
      model.addSection("Kanji")
      for item in kanji {
        model.add(item)
      }
    }

    for section in 0 ..< model.sectionCount {
      model.sortSection(section) { (itemA, itemB) -> ComparisonResult in
        if let itemA = itemA as? SubjectModelItem, let itemB = itemB as? SubjectModelItem,
          let a = itemA.assignment, let b = itemB.assignment {
          if a.isLocked, !b.isLocked { return .orderedDescending }
          if !a.isLocked, b.isLocked { return .orderedAscending }
          if a.isReviewStage, !b.isReviewStage { return .orderedAscending }
          if !a.isReviewStage, b.isReviewStage { return .orderedDescending }
          if a.isLessonStage, !b.isLessonStage { return .orderedAscending }
          if !a.isLessonStage, b.isLessonStage { return .orderedDescending }
          if a.srsStage > b.srsStage { return .orderedAscending }
          if a.srsStage < b.srsStage { return .orderedDescending }
        }
        return .orderedSame
      }

      let items = model.items(inSection: section)
      var lastAssignment: TKMAssignment?
      var index = 0
      while index < items.count {
        let assignment = (items[index] as! SubjectModelItem).assignment!
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
          model.insert(TKMListSeparatorItem(label: label), at: Int32(index), inSection: section)
          index += 1
        }
        lastAssignment = assignment
        index += 1
      }
    }

    self.model = model
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let vc = storyboard?
      .instantiateViewController(withIdentifier: "subjectDetailsViewController") as! SubjectDetailsViewController
    vc.setup(services: services, subject: subject, showHints: false, hideBackButton: false,
             index: 0)
    navigationController?.pushViewController(vc, animated: true)
  }
}
