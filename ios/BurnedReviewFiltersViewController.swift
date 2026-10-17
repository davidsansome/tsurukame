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
    
    logBurnedAssignmentsDebugInfo(burnedAssignments)
    
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
    
    logFilteringDebugInfo(allBurnedAssignments: allBurnedAssignments,
                          filteredAssignments: filteredAssignments)

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

  // MARK: - Debug Logging

  private func logBurnedAssignmentsDebugInfo(_ assignments: [TKMAssignment]) {
    #if DEBUG
    print("=== BURNED ASSIGNMENTS DEBUG INFO ===")
    print("Total burned assignments: \(assignments.count)")
    
    // Count by level and type
    var levelTypeCounts: [Int32: [TKMSubject.TypeEnum: Int]] = [:]
    for assignment in assignments {
      if levelTypeCounts[assignment.level] == nil {
        levelTypeCounts[assignment.level] = [:]
      }
      levelTypeCounts[assignment.level]![assignment.subjectType, default: 0] += 1
    }
    
    print("\n--- By Level and Type ---")
    for (level, typeCounts) in levelTypeCounts.sorted(by: { $0.key < $1.key }) {
      let radicals = typeCounts[.radical] ?? 0
      let kanji = typeCounts[.kanji] ?? 0
      let vocab = typeCounts[.vocabulary] ?? 0
      let total = radicals + kanji + vocab
      print("Level \(level): Radicals=\(radicals), Kanji=\(kanji), Vocab=\(vocab), Total=\(total)")
    }
    
    // Show high-level items (old reorganized items)
    let highLevelAssignments = assignments.filter { $0.level > 38 }
    if !highLevelAssignments.isEmpty {
      print("\n--- HIGH LEVEL ITEMS (> 38) ---")
      for assignment in highLevelAssignments.sorted(by: { $0.level < $1.level }) {
        if let subject = services.localCachingClient.getSubject(id: assignment.subjectID) {
          let subjectType = assignment.subjectType == .radical ? "Radical" : (assignment.subjectType == .kanji ? "Kanji" : "Vocab")
          let meaning = subject.primaryMeaning.isEmpty ? "NO MEANING" : subject.primaryMeaning
          print("  Level \(assignment.level), \(subjectType): \(subject.japanese) - \(meaning)")
        }
      }
    }
    
    print("\nMin level: \(assignments.map { $0.level }.min() ?? -1)")
    print("Max level: \(assignments.map { $0.level }.max() ?? -1)")
    print("=====================================")
    #endif
  }

  private func logFilteringDebugInfo(allBurnedAssignments: [TKMAssignment],
                                     filteredAssignments: [TKMAssignment]) {
    #if DEBUG
    print("=== BEFORE FILTERING ===")
    print("Total burned assignments: \(allBurnedAssignments.count)")
    
    print("=== AFTER FILTERING ===")
    print("Selected levels: \(selectedLevels.sorted())")
    print("Selected types: \(selectedTypes)")
    print("Filtered assignments: \(filteredAssignments.count)")
    
    let levelCountsAfterFilter = Dictionary(grouping: filteredAssignments, by: { $0.level })
      .mapValues { $0.count }
      .sorted { $0.key < $1.key }
    print("Levels in filtered result: \(levelCountsAfterFilter.map { "Level \($0.key): \($0.value)" }.joined(separator: ", "))")
    print("=======================")
    #endif
  }
}
