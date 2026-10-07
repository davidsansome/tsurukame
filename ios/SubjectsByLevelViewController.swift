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

// All the subjects in one level, as a page of SubjectCatalogueViewController.
class SubjectsByLevelViewController: UITableViewController, SubjectDelegate {
  private var services: TKMServices!
  private(set) var level: Int!
  private var showAnswers: Bool!
  private var model: TableModel?
  private lazy var cards = TableCards(tableView: tableView)

  // Called with the level to move to when the previous or next level button is tapped. The
  // buttons are only shown when it's set.
  var onChangeLevel: ((Int) -> Void)?
  var hasPreviousLevel = false
  var hasNextLevel = false

  func setup(services: TKMServices, level: Int, showAnswers: Bool) {
    self.services = services
    self.level = level
    self.showAnswers = showAnswers
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Level \(level!)"

    var sections: [(TKMSubject.TypeEnum, String)] =
      [(.radical, "Radicals"), (.kanji, "Kanji"), (.vocabulary, "Vocabulary")]
    var items = [TKMSubject.TypeEnum: [SubjectListItem]]()
    for assignment in services.localCachingClient.getAssignments(level: level) {
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }
      let item = SubjectListItem(subject: subject, assignment: assignment, delegate: self)
      item.showAnswers = showAnswers
      items[subject.subjectType, default: []].append(item)
    }

    let model = MutableTableModel(tableView: tableView)
    sections.removeAll { items[$0.0] == nil }
    for (type, name) in sections {
      let typeItems = items[type]!.sorted { order($0.assignment!) < order($1.assignment!) }
      let guru = typeItems.filter { $0.assignment!.srsStage >= .guru1 }.count
      model.add(section: name)
      model.sections[model.sections.count - 1].headerDetail =
        "\(guru) of \(typeItems.count) at Guru"
      for item in typeItems {
        model.add(item)
      }
    }
    cards.prepare(model)
    self.model = model

    tableView.tableHeaderView = makeHeader(itemCount: items.values.map(\.count).reduce(0, +))
  }

  // Lessons first, then reviews from the lowest SRS stage up, then locked subjects.
  private func order(_ assignment: TKMAssignment) -> Int {
    if assignment.isLocked { return 1000 }
    if assignment.isLessonStage { return -1 }
    return assignment.srsStage.rawValue
  }

  // The number of subjects, and buttons to move to the previous and next levels.
  private func makeHeader(itemCount: Int) -> UIView {
    let label = UILabel()
    label.text = "\(itemCount) items · swipe for other levels"
    label.font = UIFont.systemFont(ofSize: 14)
    label.textColor = TKMStyle.Color.grey33
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8

    let row = UIStackView(arrangedSubviews: [label])
    row.alignment = .center
    row.spacing = 8
    if onChangeLevel != nil {
      for (symbol, enabled, delta, name) in [("chevron.left", hasPreviousLevel, -1, "Previous"),
                                             ("chevron.right", hasNextLevel, 1, "Next")] {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13,
                                                                              weight: .bold))
        config.cornerStyle = .capsule
        config.baseBackgroundColor = TKMStyle.Color.cellBackground
        config.baseForegroundColor = TKMStyle.Color.label
        config.background.strokeColor = TKMStyle.Color.grey80
        config.background.strokeWidth = 1
        let button = UIButton(configuration: config)
        button.isEnabled = enabled
        button.accessibilityLabel = "\(name) level"
        button.addAction(UIAction { [unowned self] _ in
          self.onChangeLevel?(self.level + delta)
        }, for: .touchUpInside)
        NSLayoutConstraint.activate([
          button.widthAnchor.constraint(equalToConstant: 36),
          button.heightAnchor.constraint(equalToConstant: 36),
        ])
        row.addArrangedSubview(button)
      }
    }

    let header = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 52))
    row.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: header.layoutMarginsGuide.trailingAnchor),
      row.centerYAnchor.constraint(equalTo: header.centerYAnchor),
    ])
    header.preservesSuperviewLayoutMargins = true
    return header
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
