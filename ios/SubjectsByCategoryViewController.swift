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

import Foundation
import WaniKaniAPI

class SubjectsByCategoryViewController: UITableViewController, SubjectDelegate, TKMViewController {
  private var services: TKMServices!
  private(set) var category: SRSStageCategory!
  private var showAnswers: Bool!
  private var model: TableModel?
  private var answerButton: ShowAnswersButton!
  private lazy var cards = TableCards(tableView: tableView)

  func setup(services: TKMServices, category: SRSStageCategory, showAnswers: Bool) {
    self.services = services
    self.category = category
    self.showAnswers = showAnswers
  }

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = category.description
    navigationItem.largeTitleDisplayMode = .always

    answerButton = ShowAnswersButton(isOn: showAnswers)
    answerButton.onChange = { [unowned self] in self.setShowAnswers($0, animated: true) }
    let answerItem = UIBarButtonItem(customView: answerButton)
    if #available(iOS 26.0, *) {
      // The pill draws its own background.
      answerItem.hidesSharedBackground = true
    }
    navigationItem.rightBarButtonItem = answerItem

    var items = [TKMSubject.TypeEnum: [SubjectListItem]]()
    for assignment in services.localCachingClient.getAssignmentsInCategory(category: category) {
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }
      if assignment.startedAt == 0 {
        continue
      }
      let item = SubjectListItem(subject: subject, assignment: assignment, delegate: self)
      item.showAnswers = showAnswers
      items[subject.subjectType, default: []].append(item)
    }

    // Lowest SRS stage first, then by level.
    let comparator = { (a: SubjectListItem, b: SubjectListItem) -> Bool in
      let a = a.assignment!, b = b.assignment!
      if a.srsStage != b.srsStage { return a.srsStage < b.srsStage }
      return a.level < b.level
    }

    let model = MutableTableModel(tableView: tableView)
    let types: [(TKMSubject.TypeEnum, String)] =
      [(.radical, "Radicals"), (.kanji, "Kanji"), (.vocabulary, "Vocabulary")]
    for (type, name) in types {
      guard let typeItems = items[type] else { continue }
      model.add(section: name)
      model.sections[model.sections.count - 1].headerDetail = "\(typeItems.count)"
      for item in typeItems.sorted(by: comparator) {
        model.add(item)
      }
    }
    cards.prepare(model)
    self.model = model
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cards.layout()
  }

  func setShowAnswers(_ value: Bool, animated: Bool = false) {
    showAnswers = value
    if isViewLoaded {
      setSubjectListAnswersShown(value, model: model, tableView: tableView, animated: animated)
    }
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let vc = StoryboardScene.SubjectDetails.initialScene.instantiate()
    vc.setup(services: services, subject: subject)
    navigationController?.pushViewController(vc, animated: true)
  }
}
