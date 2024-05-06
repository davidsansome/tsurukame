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

import Foundation
import WaniKaniAPI

class LessonPickerViewController: UITableViewController, SubjectDelegate {
  var services: TKMServices!
  private var model: TableModel?
  private var reviewsBySubjectId: [Int64: ReviewItem] = [:]
  private var selectedItems: [Int64: ReviewItem] = [:]

  func setup(services: TKMServices) {
    self.services = services
  }

  struct ReviewsForLevel {
    var radicals: [SubjectModelItem] = []
    var kanji: [SubjectModelItem] = []
    var vocabulary: [SubjectModelItem] = []
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Lesson Picker"
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Begin", style: .plain,
                                                        target: self,
                                                        action: #selector(startLessons))
    navigationItem.rightBarButtonItem?.isEnabled = false // waiting for user to select items

    let model = MutableTableModel(tableView: tableView)
    model.add(section: "",
              footer: "Select items below to queue them up for lessons. " +
                "When you've finished selecting items, tap \"Begin\" " +
                "in the top right to start.")

    let assignments = services.localCachingClient.getAllAssignments()
    let items = ReviewItem.readyForLessons(assignments: assignments,
                                           localCachingClient: services.localCachingClient)
    var levels = [Int32: ReviewsForLevel]()
    for reviewItem in items {
      let assignment = reviewItem.assignment
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }
      reviewsBySubjectId[assignment.subjectID] = reviewItem

      let item = SubjectModelItem(subject: subject, delegate: self, assignment: assignment,
                                  readingWrong: false, meaningWrong: false)
      item.showLevelNumber = true
      item.showAnswers = false
      item.showLevelNumber = false
      item.canShowCheckmark = true
      if levels.index(forKey: assignment.level) == nil {
        levels[assignment.level] = ReviewsForLevel()
      }
      switch subject.subjectType {
      case .radical:
        levels[assignment.level]!.radicals.append(item)
      case .kanji:
        levels[assignment.level]!.kanji.append(item)
      case .vocabulary:
        levels[assignment.level]!.vocabulary.append(item)
      default:
        break
      }
    }

    for (level, data) in levels.sorted(by: { $0.key < $1.key }) {
      model.add(section: "Level \(level)")
      if !data.radicals.isEmpty {
        model.add(TKMListSeparatorItem(label: "Radicals (\(data.radicals.count))"))
      }
      for item in data.radicals {
        model.add(item)
      }
      if !data.kanji.isEmpty {
        model.add(TKMListSeparatorItem(label: "Kanji (\(data.kanji.count))"))
      }
      for item in data.kanji {
        model.add(item)
      }
      if !data.vocabulary.isEmpty {
        model.add(TKMListSeparatorItem(label: "Vocabulary (\(data.vocabulary.count))"))
      }
      for item in data.vocabulary {
        model.add(item)
      }
    }
    self.model = model
  }

  @objc func startLessons() {
    performSegue(withIdentifier: "startCustomLessons", sender: self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "startCustomLessons":
      if selectedItems.count == 0 {
        return
      }
      let vc = segue.destination as! LessonsViewController
      vc.setup(services: services, items: Array(selectedItems.values))
    default:
      break
    }
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let hasItem = selectedItems.index(forKey: subject.id) != nil
    if hasItem {
      selectedItems.removeValue(forKey: subject.id)
    } else {
      selectedItems[subject.id] = reviewsBySubjectId[subject.id]
    }
    navigationItem.rightBarButtonItem?.title = selectedItems
      .count > 0 ? "Begin (\(selectedItems.count))" : "Begin"
    navigationItem.rightBarButtonItem?.isEnabled = selectedItems.count > 0
  }
}
