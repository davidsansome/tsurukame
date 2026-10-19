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

class BurnedReviewFiltersViewController: UIViewController, TKMViewController {
  var services: TKMServices!

  private var selectedLevels: Set<Int32> = []
  private var selectedTypes: Set<TKMSubject.TypeEnum> = [.radical, .kanji, .vocabulary]
  private var availableLevels: [Int32] = []

  private var burnedCounts: [TKMSubject.TypeEnum: Int] = [:]

  // UI Components
  private let scrollView = UIScrollView()
  private let contentStackView = UIStackView()

  // Subject Type Cards
  private var radicalCard: SubjectTypeCardView!
  private var kanjiCard: SubjectTypeCardView!
  private var vocabularyCard: SubjectTypeCardView!

  // Level selection
  private var levelRangeChips: [LevelRangeChipView] = []
  private var individualLevelChips: [LevelChipView] = []

  // Footer
  private let footerView = UIView()
  private let countLabel = UILabel()
  private let startButton = UIButton(type: .system)

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
    view.backgroundColor = TKMStyle.Color.background

    // Get all available burned levels
    let burnedAssignments = services.localCachingClient.getAllBurnedAssignments()

    // Calculate counts by type
    burnedCounts = [
      .radical: burnedAssignments.filter { $0.subjectType == .radical }.count,
      .kanji: burnedAssignments.filter { $0.subjectType == .kanji }.count,
      .vocabulary: burnedAssignments.filter { $0.subjectType == .vocabulary }.count,
    ]

    availableLevels = Array(Set(burnedAssignments.map { $0.level })).sorted()
    selectedLevels = Set(availableLevels)

    setupUI()
  }

  // MARK: - UI Setup

  private func setupUI() {
    // Scroll view
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)

    // Content stack
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.axis = .vertical
    contentStackView.spacing = 24
    scrollView.addSubview(contentStackView)

    // Footer
    footerView.translatesAutoresizingMaskIntoConstraints = false
    footerView.backgroundColor = TKMStyle.Color.cellBackground
    footerView.layer.shadowColor = UIColor.black.cgColor
    footerView.layer.shadowOffset = CGSize(width: 0, height: -2)
    footerView.layer.shadowOpacity = 0.1
    footerView.layer.shadowRadius = 8
    view.addSubview(footerView)

    // Constraints
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
      contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

      footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    setupSubjectTypeSection()
    setupLevelRangeSection()
    setupIndividualLevelsSection()
    setupFooter()

    updateItemCount()
  }

  private func setupSubjectTypeSection() {
    let sectionView = createSectionView(title: "SELECT SUBJECT TYPES")

    // Add Select All / None buttons
    let buttonsStackView = UIStackView()
    buttonsStackView.axis = .horizontal
    buttonsStackView.spacing = 12
    buttonsStackView.distribution = .fillEqually

    let selectAllButton = createSelectionButton(title: "Select All") { [weak self] in
      self?.selectAllTypes()
    }
    let selectNoneButton = createSelectionButton(title: "Select None") { [weak self] in
      self?.selectNoTypes()
    }

    buttonsStackView.addArrangedSubview(selectAllButton)
    buttonsStackView.addArrangedSubview(selectNoneButton)

    let buttonsContainer = UIView()
    buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
    buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
    buttonsContainer.addSubview(buttonsStackView)

    NSLayoutConstraint.activate([
      buttonsStackView.topAnchor.constraint(equalTo: buttonsContainer.topAnchor),
      buttonsStackView.leadingAnchor.constraint(equalTo: buttonsContainer.leadingAnchor,
                                                constant: 16),
      buttonsStackView.trailingAnchor.constraint(equalTo: buttonsContainer.trailingAnchor,
                                                 constant: -16),
      buttonsStackView.bottomAnchor.constraint(equalTo: buttonsContainer.bottomAnchor),
      selectAllButton.heightAnchor.constraint(equalToConstant: 36),
    ])

    sectionView.addArrangedSubview(buttonsContainer)

    // Cards stack with padding
    let cardsContainer = UIView()
    cardsContainer.translatesAutoresizingMaskIntoConstraints = false

    let cardsStackView = UIStackView()
    cardsStackView.translatesAutoresizingMaskIntoConstraints = false
    cardsStackView.axis = .horizontal
    cardsStackView.distribution = .fillEqually
    cardsStackView.spacing = 12

    radicalCard = SubjectTypeCardView(subjectType: .radical,
                                      count: burnedCounts[.radical] ?? 0,
                                      delegate: self)
    radicalCard.isSelected = selectedTypes.contains(.radical)

    kanjiCard = SubjectTypeCardView(subjectType: .kanji,
                                    count: burnedCounts[.kanji] ?? 0,
                                    delegate: self)
    kanjiCard.isSelected = selectedTypes.contains(.kanji)

    vocabularyCard = SubjectTypeCardView(subjectType: .vocabulary,
                                         count: burnedCounts[.vocabulary] ?? 0,
                                         delegate: self)
    vocabularyCard.isSelected = selectedTypes.contains(.vocabulary)

    cardsStackView.addArrangedSubview(radicalCard)
    cardsStackView.addArrangedSubview(kanjiCard)
    cardsStackView.addArrangedSubview(vocabularyCard)

    cardsContainer.addSubview(cardsStackView)

    NSLayoutConstraint.activate([
      cardsStackView.topAnchor.constraint(equalTo: cardsContainer.topAnchor),
      cardsStackView.leadingAnchor.constraint(equalTo: cardsContainer.leadingAnchor, constant: 16),
      cardsStackView.trailingAnchor.constraint(equalTo: cardsContainer.trailingAnchor,
                                               constant: -16),
      cardsStackView.bottomAnchor.constraint(equalTo: cardsContainer.bottomAnchor),
    ])

    sectionView.addArrangedSubview(cardsContainer)
    contentStackView.addArrangedSubview(sectionView)
  }

  private func setupLevelRangeSection() {
    let sectionView = createSectionView(title: "SELECT LEVEL RANGES")

    // Add Select All / None buttons
    let buttonsStackView = UIStackView()
    buttonsStackView.axis = .horizontal
    buttonsStackView.spacing = 12
    buttonsStackView.distribution = .fillEqually

    let selectAllButton = createSelectionButton(title: "Select All") { [weak self] in
      self?.selectAllLevels()
    }
    let selectNoneButton = createSelectionButton(title: "Select None") { [weak self] in
      self?.selectNoLevels()
    }

    buttonsStackView.addArrangedSubview(selectAllButton)
    buttonsStackView.addArrangedSubview(selectNoneButton)

    let buttonsContainer = UIView()
    buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
    buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
    buttonsContainer.addSubview(buttonsStackView)

    NSLayoutConstraint.activate([
      buttonsStackView.topAnchor.constraint(equalTo: buttonsContainer.topAnchor),
      buttonsStackView.leadingAnchor.constraint(equalTo: buttonsContainer.leadingAnchor,
                                                constant: 16),
      buttonsStackView.trailingAnchor.constraint(equalTo: buttonsContainer.trailingAnchor,
                                                 constant: -16),
      buttonsStackView.bottomAnchor.constraint(equalTo: buttonsContainer.bottomAnchor),
      selectAllButton.heightAnchor.constraint(equalToConstant: 36),
    ])

    sectionView.addArrangedSubview(buttonsContainer)

    // Create range chips grid using stack views
    let ranges: [(Int32, Int32)] = [
      (1, 5), (6, 10), (11, 15), (16, 20), (21, 25),
      (26, 30), (31, 35), (36, 40), (41, 45), (46, 50),
      (51, 55), (56, 60),
    ]

    // Filter to only show ranges that have levels
    let validRanges = ranges.filter { range in
      availableLevels.contains(where: { $0 >= range.0 && $0 <= range.1 })
    }

    let chipsPerRow = 3
    let horizontalSpacing: CGFloat = 8
    let verticalSpacing: CGFloat = 8

    let mainStackView = UIStackView()
    mainStackView.axis = .vertical
    mainStackView.spacing = verticalSpacing
    mainStackView.distribution = .fillEqually

    var currentRowStack: UIStackView?

    for (index, range) in validRanges.enumerated() {
      if index % chipsPerRow == 0 {
        currentRowStack = UIStackView()
        currentRowStack?.axis = .horizontal
        currentRowStack?.spacing = horizontalSpacing
        currentRowStack?.distribution = .fillEqually
        mainStackView.addArrangedSubview(currentRowStack!)
      }

      let chip = LevelRangeChipView(startLevel: range.0, endLevel: range.1, delegate: self)

      // Check if all levels in range are selected
      let levelsInRange = availableLevels.filter { $0 >= range.0 && $0 <= range.1 }
      chip.isSelected = levelsInRange.allSatisfy { selectedLevels.contains($0) }

      currentRowStack?.addArrangedSubview(chip)
      levelRangeChips.append(chip)
    }

    // Fill remaining spaces in last row with empty views
    if let lastRow = currentRowStack {
      let itemsInLastRow = validRanges.count % chipsPerRow
      if itemsInLastRow > 0 {
        for _ in itemsInLastRow ..< chipsPerRow {
          let spacer = UIView()
          lastRow.addArrangedSubview(spacer)
        }
      }
    }

    // Add padding container
    let rangesContainer = UIView()
    rangesContainer.translatesAutoresizingMaskIntoConstraints = false
    mainStackView.translatesAutoresizingMaskIntoConstraints = false
    rangesContainer.addSubview(mainStackView)

    NSLayoutConstraint.activate([
      mainStackView.topAnchor.constraint(equalTo: rangesContainer.topAnchor),
      mainStackView.leadingAnchor.constraint(equalTo: rangesContainer.leadingAnchor, constant: 16),
      mainStackView.trailingAnchor.constraint(equalTo: rangesContainer.trailingAnchor,
                                              constant: -16),
      mainStackView.bottomAnchor.constraint(equalTo: rangesContainer.bottomAnchor),
    ])

    sectionView.addArrangedSubview(rangesContainer)
    contentStackView.addArrangedSubview(sectionView)
  }

  private func setupIndividualLevelsSection() {
    let sectionView = createSectionView(title: "OR SELECT INDIVIDUAL LEVELS")

    // Create individual level chips using stack views
    let chipsPerRow = 5
    let horizontalSpacing: CGFloat = 8
    let verticalSpacing: CGFloat = 8

    let mainStackView = UIStackView()
    mainStackView.axis = .vertical
    mainStackView.spacing = verticalSpacing
    mainStackView.distribution = .fillEqually

    var currentRowStack: UIStackView?

    for (index, level) in availableLevels.enumerated() {
      if index % chipsPerRow == 0 {
        currentRowStack = UIStackView()
        currentRowStack?.axis = .horizontal
        currentRowStack?.spacing = horizontalSpacing
        currentRowStack?.distribution = .fillEqually
        mainStackView.addArrangedSubview(currentRowStack!)
      }

      let chip = LevelChipView(level: level, delegate: self)
      chip.isSelected = selectedLevels.contains(level)

      currentRowStack?.addArrangedSubview(chip)
      individualLevelChips.append(chip)
    }

    // Fill remaining spaces in last row with empty views
    if let lastRow = currentRowStack {
      let itemsInLastRow = availableLevels.count % chipsPerRow
      if itemsInLastRow > 0 {
        for _ in itemsInLastRow ..< chipsPerRow {
          let spacer = UIView()
          lastRow.addArrangedSubview(spacer)
        }
      }
    }

    // Add padding container
    let levelsContainer = UIView()
    levelsContainer.translatesAutoresizingMaskIntoConstraints = false
    mainStackView.translatesAutoresizingMaskIntoConstraints = false
    levelsContainer.addSubview(mainStackView)

    NSLayoutConstraint.activate([
      mainStackView.topAnchor.constraint(equalTo: levelsContainer.topAnchor),
      mainStackView.leadingAnchor.constraint(equalTo: levelsContainer.leadingAnchor, constant: 16),
      mainStackView.trailingAnchor.constraint(equalTo: levelsContainer.trailingAnchor,
                                              constant: -16),
      mainStackView.bottomAnchor.constraint(equalTo: levelsContainer.bottomAnchor),
    ])

    sectionView.addArrangedSubview(levelsContainer)
    contentStackView.addArrangedSubview(sectionView)
  }

  private func setupFooter() {
    countLabel.translatesAutoresizingMaskIntoConstraints = false
    countLabel.font = .systemFont(ofSize: 16, weight: .semibold)
    countLabel.textColor = TKMStyle.Color.grey33
    countLabel.textAlignment = .center
    footerView.addSubview(countLabel)

    startButton.translatesAutoresizingMaskIntoConstraints = false
    startButton.setTitle("Start Review", for: .normal)
    startButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
    startButton.backgroundColor = TKMStyle.defaultTintColor
    startButton.setTitleColor(.white, for: .normal)
    startButton.layer.cornerRadius = 25
    startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    footerView.addSubview(startButton)

    NSLayoutConstraint.activate([
      countLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),
      countLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
      countLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),

      startButton.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
      startButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
      startButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
      startButton.heightAnchor.constraint(equalToConstant: 50),
      startButton.bottomAnchor.constraint(equalTo: footerView.safeAreaLayoutGuide.bottomAnchor,
                                          constant: -8),
    ])
  }

  private func createSectionView(title: String) -> UIStackView {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 12

    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    titleLabel.textColor = TKMStyle.Color.grey33

    let titleContainer = UIView()
    titleContainer.addSubview(titleLabel)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: titleContainer.topAnchor),
      titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor, constant: -16),
      titleLabel.bottomAnchor.constraint(equalTo: titleContainer.bottomAnchor),
    ])

    stackView.addArrangedSubview(titleContainer)
    return stackView
  }

  private func createSelectionButton(title: String,
                                     action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
    button.backgroundColor = TKMStyle.Color.cellBackground
    button.setTitleColor(TKMStyle.Color.accent, for: .normal)
    button.layer.cornerRadius = 18
    button.layer.borderWidth = 1
    button.layer.borderColor = TKMStyle.Color.separator.cgColor

    let tapAction = UIAction { _ in action() }
    button.addAction(tapAction, for: .touchUpInside)

    return button
  }

  private func selectAllTypes() {
    selectedTypes = [.radical, .kanji, .vocabulary]
    radicalCard.isSelected = true
    kanjiCard.isSelected = true
    vocabularyCard.isSelected = true
    updateItemCount()
  }

  private func selectNoTypes() {
    selectedTypes = []
    radicalCard.isSelected = false
    kanjiCard.isSelected = false
    vocabularyCard.isSelected = false
    updateItemCount()
  }

  private func selectAllLevels() {
    selectedLevels = Set(availableLevels)
    for chip in individualLevelChips {
      chip.isSelected = true
    }
    for chip in levelRangeChips {
      let levelsInRange = availableLevels.filter { $0 >= chip.startLevel && $0 <= chip.endLevel }
      chip.isSelected = !levelsInRange.isEmpty
    }
    updateItemCount()
  }

  private func selectNoLevels() {
    selectedLevels = []
    for chip in individualLevelChips {
      chip.isSelected = false
    }
    for chip in levelRangeChips {
      chip.isSelected = false
    }
    updateItemCount()
  }

  private func updateItemCount() {
    let allBurnedAssignments = services.localCachingClient.getAllBurnedAssignments()
    let filteredAssignments = allBurnedAssignments.filter { assignment in
      selectedLevels.contains(assignment.level) &&
        selectedTypes.contains(assignment.subjectType)
    }

    let count = filteredAssignments.count
    countLabel.text = "📊 \(count) items ready"
  }

  // MARK: - Actions

  @objc func startButtonTapped() {
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

// MARK: - SubjectTypeCardDelegate

extension BurnedReviewFiltersViewController: SubjectTypeCardDelegate {
  func didTapSubjectTypeCard(_ card: SubjectTypeCardView) {
    if selectedTypes.contains(card.subjectType) {
      selectedTypes.remove(card.subjectType)
      card.isSelected = false
    } else {
      selectedTypes.insert(card.subjectType)
      card.isSelected = true
    }
    updateItemCount()
  }
}

// MARK: - LevelRangeChipDelegate

extension BurnedReviewFiltersViewController: LevelRangeChipDelegate {
  func didTapLevelRangeChip(_ chip: LevelRangeChipView) {
    let levelsInRange = availableLevels.filter { $0 >= chip.startLevel && $0 <= chip.endLevel }

    if chip.isSelected {
      // Deselect all levels in range
      levelsInRange.forEach { selectedLevels.remove($0) }
      chip.isSelected = false
    } else {
      // Select all levels in range
      levelsInRange.forEach { selectedLevels.insert($0) }
      chip.isSelected = true
    }

    // Update individual level chips
    for levelChip in individualLevelChips {
      if levelsInRange.contains(levelChip.level) {
        levelChip.isSelected = selectedLevels.contains(levelChip.level)
      }
    }

    updateItemCount()
  }
}

// MARK: - LevelChipDelegate

extension BurnedReviewFiltersViewController: LevelChipDelegate {
  func didTapLevelChip(_ chip: LevelChipView) {
    if selectedLevels.contains(chip.level) {
      selectedLevels.remove(chip.level)
      chip.isSelected = false
    } else {
      selectedLevels.insert(chip.level)
      chip.isSelected = true
    }

    // Update range chips
    for rangeChip in levelRangeChips {
      let levelsInRange = availableLevels
        .filter { $0 >= rangeChip.startLevel && $0 <= rangeChip.endLevel }
      rangeChip.isSelected = levelsInRange.allSatisfy { selectedLevels.contains($0) }
    }

    updateItemCount()
  }
}
