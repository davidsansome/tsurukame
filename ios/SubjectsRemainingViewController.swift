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
import WaniKaniAPI

class SubjectsRemainingViewController: UITableViewController, SubjectDelegate,
  TKMViewController {
  var services: TKMServices!
  var model: TableModel?

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

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
      item.showAnswers = true
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

    let model = MutableTableModel(tableView: tableView)
    if !radicals.isEmpty {
      model.add(section: "Radicals")
      for item in radicals {
        model.add(item)
      }
    }
    if !kanji.isEmpty {
      model.add(section: "Kanji")
      for item in kanji {
        model.add(item)
      }
    }

    for section in 0 ..< model.sectionCount {
      model.sort(section: section) { (itemA: SubjectModelItem, itemB: SubjectModelItem) -> Bool in
        if let a = itemA.assignment, let b = itemB.assignment {
          if a.isLocked, !b.isLocked { return false }
          if !a.isLocked, b.isLocked { return true }
          if a.isReviewStage, !b.isReviewStage { return true }
          if !a.isReviewStage, b.isReviewStage { return false }
          if a.isLessonStage, !b.isLessonStage { return true }
          if !a.isLessonStage, b.isLessonStage { return false }
          if a.srsStage > b.srsStage { return true }
          if a.srsStage < b.srsStage { return false }
        }
        return false
      }

      let items = model.items(inSection: section)
      var lastAssignment: TKMAssignment?
      var index = 0
      for item in items {
        let assignment = (item as! SubjectModelItem).assignment!
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
          model.insert(TKMListSeparatorItem(label: label), atIndex: index, inSection: section)
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
