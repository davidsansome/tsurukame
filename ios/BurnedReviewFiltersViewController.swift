// Copyright David Sansome
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
import UIKit
import WaniKaniAPI

class BurnedReviewFiltersViewController: UITableViewController, TKMViewController {
  var services: TKMServices!

  private var selectedLevels: Set<Int32> = []
  private var selectedTypes: Set<TKMSubject.TypeEnum> = [.radical, .kanji, .vocabulary]
  private var availableLevels: [Int32] = []
  private var model: TableModel?  // IMPORTANTE: Guardar la referencia al modelo

  var canSwipeToGoBack: Bool { true }

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard services != nil else {
      fatalError("BurnedReviewFiltersViewController.setup(services:) must be called before viewDidLoad")
    }
    
    navigationItem.title = "Review Burned Items"
    tableView.backgroundColor = TKMStyle.Color.background

    // Get all available burned levels
    let burnedAssignments = services.localCachingClient.getAllBurnedAssignments()
    availableLevels = Array(Set(burnedAssignments.map { $0.level })).sorted()

    // Initialize selected levels to all available
    selectedLevels = Set(availableLevels)

    reloadModel()
  }

  private func reloadModel() {
    let model = MutableTableModel(tableView: tableView)

    // MARK: - Types Section
    model.add(section: "Subject Types")

    // Select All / Select None buttons for types
    model.add(BasicModelItem(style: .default,
                             title: "Select All",
                             subtitle: nil,
                             accessoryType: .none,
                             tapHandler: { [weak self] in
      self?.selectedTypes = [.radical, .kanji, .vocabulary]
      self?.reloadModel()
    }))

    model.add(BasicModelItem(style: .default,
                             title: "Select None",
                             subtitle: nil,
                             accessoryType: .none,
                             tapHandler: { [weak self] in
      self?.selectedTypes = []
      self?.reloadModel()
    }))

    // Type checkboxes
    let types: [(TKMSubject.TypeEnum, String)] = [
      (.radical, "Radicals"),
      (.kanji, "Kanji"),
      (.vocabulary, "Vocabulary"),
    ]

    for (type, name) in types {
      let isSelected = selectedTypes.contains(type)
      model.add(SwitchModelItem(style: .default,
                                title: name,
                                subtitle: nil,
                                on: isSelected,
                                switchHandler: { [weak self] switchView in
        if switchView.isOn {
          self?.selectedTypes.insert(type)
        } else {
          self?.selectedTypes.remove(type)
        }
        // NOTE: No llamamos a reloadModel() - solo actualizamos el estado
      }))
    }

    // MARK: - Levels Section
    model.add(section: "Levels")

    // Select All / Select None buttons for levels
    model.add(BasicModelItem(style: .default,
                             title: "Select All",
                             subtitle: nil,
                             accessoryType: .none,
                             tapHandler: { [weak self] in
      self?.selectedLevels = Set(self?.availableLevels ?? [])
      self?.reloadModel()
    }))

    model.add(BasicModelItem(style: .default,
                             title: "Select None",
                             subtitle: nil,
                             accessoryType: .none,
                             tapHandler: { [weak self] in
      self?.selectedLevels = []
      self?.reloadModel()
    }))

    // Level checkboxes
    for level in availableLevels {
      let isSelected = selectedLevels.contains(level)
      let title = "Level \(level)"
      model.add(SwitchModelItem(style: .default,
                                title: title,
                                subtitle: nil,
                                on: isSelected,
                                switchHandler: { [weak self] switchView in
        if switchView.isOn {
          self?.selectedLevels.insert(level)
        } else {
          self?.selectedLevels.remove(level)
        }
        // NOTE: No llamamos a reloadModel() - solo actualizamos el estado
      }))
    }

    self.model = model  // IMPORTANTE: Guardar la referencia
    model.reloadTable()
  }

  // MARK: - Actions

  @objc func startButtonTapped(_ sender: UIBarButtonItem) {
    guard selectedLevels.count > 0, selectedTypes.count > 0 else {
      let alert = UIAlertController(title: "No Filters Selected",
                                     message: "Please select at least one level and one type.",
                                     preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
      return
    }

    // Get filtered burned assignments
    let allBurnedAssignments = services.localCachingClient.getAllBurnedAssignments()
    let filteredAssignments = allBurnedAssignments.filter { assignment in
      selectedLevels.contains(assignment.level) &&
      selectedTypes.contains(assignment.subjectType)
    }

    let items = ReviewItem.readyForBurnedReview(assignments: filteredAssignments,
                                                localCachingClient: services.localCachingClient)
      .shuffled()

    if items.count == 0 {
      let alert = UIAlertController(title: "No Items",
                                     message: "No burned items match your filters.",
                                     preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
      return
    }

    // Navigate to review container using StoryboardScene
    let vc = StoryboardScene.ReviewContainer.initialScene.instantiate()
    vc.setup(services: services, items: items, isPracticeSession: true)
    navigationController?.pushViewController(vc, animated: true)
  }
}
