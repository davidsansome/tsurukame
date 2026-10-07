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
import WaniKaniAPI

class SubjectsRemainingViewController: UITableViewController, SubjectDelegate,
  TKMViewController {
  var services: TKMServices!
  var model: TableModel?
  private var level: Int = 0
  private lazy var cards = TableCards(tableView: tableView)

  func setup(services: TKMServices, level: Int) {
    self.services = services
    self.level = level
  }

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Remaining"
    navigationItem.largeTitleDisplayMode = .always

    var items = [TKMSubject.TypeEnum: [SubjectListItem]]()
    for assignment in services.localCachingClient.getAssignments(level: level) {
      if assignment.srsStage > .apprentice4 {
        continue
      }
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }
      if !Settings.showPreviousLevelGraph, subject.subjectType == .vocabulary {
        continue
      }
      let item = SubjectListItem(subject: subject, assignment: assignment, delegate: self)
      item.detail = .remaining
      items[subject.subjectType, default: []].append(item)
    }

    // Whatever can be done now comes first: reviews, then lessons, then the rest from the highest
    // SRS stage down, with locked subjects last.
    func order(_ a: TKMAssignment) -> Int {
      if a.isLocked { return 1000 }
      if a.isReviewStage, let date = a.reviewDate, date <= Date() { return -2 }
      if a.isLessonStage { return -1 }
      return 100 - a.srsStage.rawValue
    }

    let model = MutableTableModel(tableView: tableView)
    let types: [(TKMSubject.TypeEnum, String)] =
      [(.radical, "Radicals"), (.kanji, "Kanji"), (.vocabulary, "Vocabulary")]
    for (type, name) in types {
      guard let typeItems = items[type] else { continue }
      model.add(section: name)
      model.sections[model.sections.count - 1].headerDetail = "\(typeItems.count) left"
      for item in typeItems.sorted(by: { order($0.assignment!) < order($1.assignment!) }) {
        model.add(item)
      }
    }
    cards.prepare(model)
    self.model = model

    let count = items.values.map(\.count).reduce(0, +)
    let label = UILabel()
    label.text = "Level \(level) · \(count) \(count == 1 ? "item" : "items") to Guru"
    label.font = UIFont.systemFont(ofSize: 14)
    label.textColor = TKMStyle.Color.grey33
    let header = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 36))
    header.preservesSuperviewLayoutMargins = true
    label.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
      label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
    ])
    tableView.tableHeaderView = header
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cards.layout()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let vc = StoryboardScene.SubjectDetails.initialScene.instantiate()
    vc.setup(services: services, subject: subject, showHints: false, hideBackButton: false,
             index: 0)
    navigationController?.pushViewController(vc, animated: true)
  }
}
