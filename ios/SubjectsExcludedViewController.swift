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

class SubjectsExcludedViewController: UITableViewController, SubjectDelegate, TKMViewController {
  private var services: TKMServices!
  private var model: TableModel?
  private var shouldReload: Bool = false
  private lazy var cards = TableCards(tableView: tableView)

  func setup(services: TKMServices, category _: SRSStageCategory, showAnswers _: Bool) {
    self.services = services
  }

  // MARK: - TKMViewController

  var canSwipeToGoBack: Bool { true }

  // MARK: - UIViewController

  func getItems() -> [SubjectListItem] {
    var items = [SubjectListItem]()
    for assignment in services.localCachingClient.getExcludedAssignments() {
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID)
      else {
        continue
      }
      items.append(SubjectListItem(subject: subject, assignment: assignment, delegate: self))
    }
    return items
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Excluded items"
    navigationItem.largeTitleDisplayMode = .always
    let model = MutableTableModel(tableView: tableView)

    let exclusions = getItems()
    model.add(section: "Vocabulary")
    model.sections[0].headerDetail = "\(exclusions.count)"
    for item in exclusions {
      model.add(item)
    }
    cards.prepare(model)

    self.model = model
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cards.layout()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
    if shouldReload {
      viewDidLoad()
    }
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    shouldReload = true
    let vc = StoryboardScene.SubjectDetails.initialScene.instantiate()
    vc.setup(services: services, subject: subject)
    navigationController?.pushViewController(vc, animated: true)
  }
}
