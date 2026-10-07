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
import UIKit
import WaniKaniAPI

private let kColumns = 4
private let kTileHeight: CGFloat = 84
private let kTileSpacing: CGFloat = 8
private let kSectionHeaderKind = UICollectionView.elementKindSectionHeader

// Lessons available to pick, as a grid of coloured tiles grouped by level and subject type. Tapping
// tiles selects them, and the bar along the bottom starts lessons for the selection.
class LessonPickerViewController: UIViewController, UICollectionViewDataSource,
  UICollectionViewDelegate {
  var services: TKMServices!

  private struct Group {
    let title: String
    let items: [(subject: TKMSubject, reviewItem: ReviewItem)]
  }

  private var groups = [Group]()
  private var selectedItems: [Int64: ReviewItem] = [:]

  private var collectionView: UICollectionView!
  private let bottomBar = LessonPickerBottomBar()

  func setup(services: TKMServices) {
    self.services = services
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Lesson picker"
    navigationItem.largeTitleDisplayMode = .always
    view.backgroundColor = TKMStyle.Color.background
    loadGroups()

    collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
    collectionView.backgroundColor = TKMStyle.Color.background
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.allowsMultipleSelection = true
    collectionView.register(LessonPickerTileCell.self, forCellWithReuseIdentifier: "tile")
    collectionView.register(LessonPickerHeaderView.self,
                            forSupplementaryViewOfKind: kSectionHeaderKind,
                            withReuseIdentifier: "header")
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(collectionView)

    bottomBar.startButton.addAction(UIAction { [unowned self] _ in
      self.perform(segue: StoryboardSegue.LessonPicker.startCustomLessons, sender: self)
    }, for: .touchUpInside)
    bottomBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bottomBar)

    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    updateSelection()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // Keep the last row clear of the bottom bar.
    let inset = bottomBar.frame.height - view.safeAreaInsets.bottom
    if collectionView.contentInset.bottom != inset {
      collectionView.contentInset.bottom = inset
      collectionView.verticalScrollIndicatorInsets.bottom = inset
    }
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.LessonPicker(segue) {
    case .startCustomLessons:
      let vc = segue.destination as! LessonsViewController
      vc.setup(services: services, items: Array(selectedItems.values))
    default:
      break
    }
  }

  // MARK: - Data

  private func loadGroups() {
    let assignments = services.localCachingClient.getNonExcludedAssignments()
    let reviewItems = ReviewItem.readyForLessons(assignments: assignments,
                                                 localCachingClient: services.localCachingClient)
    var byLevelAndType = [Int32: [TKMSubject.TypeEnum: [(TKMSubject, ReviewItem)]]]()
    for reviewItem in reviewItems {
      let assignment = reviewItem.assignment
      guard let subject = services.localCachingClient.getSubject(id: assignment.subjectID) else {
        continue
      }
      byLevelAndType[assignment.level, default: [:]][subject.subjectType, default: []]
        .append((subject, reviewItem))
    }

    let types: [(TKMSubject.TypeEnum, String)] =
      [(.radical, "Radicals"), (.kanji, "Kanji"), (.vocabulary, "Vocabulary")]
    for (level, byType) in byLevelAndType.sorted(by: { $0.key < $1.key }) {
      for (type, name) in types {
        if let items = byType[type], !items.isEmpty {
          groups.append(Group(title: "Level \(level) · \(name)",
                              items: items.map { (subject: $0.0, reviewItem: $0.1) }))
        }
      }
    }
  }

  private func updateSelection() {
    bottomBar.count = selectedItems.count
  }

  // MARK: - Layout

  private func makeLayout() -> UICollectionViewLayout {
    // Each tile is padded by half the spacing, so the section is inset by that much less.
    let halfSpacing = kTileSpacing / 2
    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1 / CGFloat(kColumns)),
                                          heightDimension: .fractionalHeight(1))
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    item.contentInsets = .init(top: halfSpacing, leading: halfSpacing, bottom: halfSpacing,
                               trailing: halfSpacing)
    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                           heightDimension: .absolute(kTileHeight + kTileSpacing))
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.contentInsets = .init(top: 0, leading: 16 - halfSpacing, bottom: 14 - halfSpacing,
                                  trailing: 16 - halfSpacing)
    let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                            heightDimension: .estimated(30))
    let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                             elementKind: kSectionHeaderKind,
                                                             alignment: .top)
    section.boundarySupplementaryItems = [header]
    return UICollectionViewCompositionalLayout(section: section)
  }

  // MARK: - UICollectionViewDataSource

  func numberOfSections(in _: UICollectionView) -> Int {
    groups.count
  }

  func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    groups[section].items.count
  }

  func collectionView(_ collectionView: UICollectionView,
                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tile", for: indexPath)
      as! LessonPickerTileCell
    cell.subject = groups[indexPath.section].items[indexPath.item].subject
    return cell
  }

  func collectionView(_ collectionView: UICollectionView,
                      viewForSupplementaryElementOfKind kind: String,
                      at indexPath: IndexPath) -> UICollectionReusableView {
    let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                 withReuseIdentifier: "header",
                                                                 for: indexPath)
      as! LessonPickerHeaderView
    header.title = groups[indexPath.section].title
    return header
  }

  // MARK: - UICollectionViewDelegate

  func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let item = groups[indexPath.section].items[indexPath.item]
    selectedItems[item.subject.id] = item.reviewItem
    updateSelection()
  }

  func collectionView(_: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    selectedItems.removeValue(forKey: groups[indexPath.section].items[indexPath.item].subject.id)
    updateSelection()
  }
}

// A subject in its type's colour, with its primary meaning underneath. When selected it gets an
// ink ring and a check badge.
private class LessonPickerTileCell: UICollectionViewCell {
  private let japaneseLabel = UILabel()
  private let meaningLabel = UILabel()
  private let ring = UIView()
  private let badge = UIImageView()

  var subject: TKMSubject! {
    didSet {
      contentView.backgroundColor = TKMStyle.color2(forSubjectType: subject.subjectType)
      japaneseLabel.attributedText = japaneseText(subject, imageSize: 26)
      meaningLabel.text = subject.primaryMeaning
      accessibilityLabel = "\(subject.japanese), \(subject.primaryMeaning)"
    }
  }

  override var isSelected: Bool {
    didSet { updateSelection() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    isAccessibilityElement = true
    contentView.layer.cornerRadius = 16
    contentView.layer.cornerCurve = .continuous

    // The ring sits outside the tile with a gap of paper between them.
    ring.layer.cornerRadius = 21
    ring.layer.cornerCurve = .continuous
    ring.layer.borderWidth = 2
    ring.isUserInteractionEnabled = false
    ring.translatesAutoresizingMaskIntoConstraints = false
    insertSubview(ring, at: 0)

    japaneseLabel.font = UIFont(name: TKMStyle.japaneseFontName, size: 26)
    japaneseLabel.textColor = .white
    japaneseLabel.textAlignment = .center
    japaneseLabel.adjustsFontSizeToFitWidth = true
    japaneseLabel.minimumScaleFactor = 0.5
    meaningLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
    meaningLabel.textColor = .white
    meaningLabel.textAlignment = .center
    meaningLabel.lineBreakMode = .byTruncatingTail
    let stack = UIStackView(arrangedSubviews: [japaneseLabel, meaningLabel])
    stack.axis = .vertical
    stack.spacing = 4
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)

    badge.image = UIImage(systemName: "checkmark",
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 10,
                                                                         weight: .heavy))
    badge.contentMode = .center
    badge.layer.cornerRadius = 11
    badge.layer.borderWidth = 2
    badge.clipsToBounds = true
    badge.translatesAutoresizingMaskIntoConstraints = false
    addSubview(badge)

    NSLayoutConstraint.activate([
      ring.topAnchor.constraint(equalTo: topAnchor, constant: -5),
      ring.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -5),
      ring.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 5),
      ring.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 5),
      stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
      badge.widthAnchor.constraint(equalToConstant: 22),
      badge.heightAnchor.constraint(equalToConstant: 22),
      badge.topAnchor.constraint(equalTo: topAnchor, constant: -4),
      badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4),
    ])
    updateSelection()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateSelection()
  }

  private func updateSelection() {
    ring.isHidden = !isSelected
    badge.isHidden = !isSelected
    ring.layer.borderColor = TKMStyle.Color.label.resolvedColor(with: traitCollection).cgColor
    badge.backgroundColor = TKMStyle.Color.label
    badge.tintColor = TKMStyle.Color.background
    badge.layer.borderColor = TKMStyle.Color.background.resolvedColor(with: traitCollection)
      .cgColor
    accessibilityTraits = isSelected ? [.button, .selected] : .button
  }
}

private class LessonPickerHeaderView: UICollectionReusableView {
  private let label = UILabel()

  var title: String? {
    didSet {
      label.attributedText = NSAttributedString(string: (title ?? "").uppercased(), attributes: [
        .font: UIFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: TKMStyle.Color.grey33,
        .kern: 1.6,
      ])
    }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// "N selected" and the Start lessons button, over a paper bar along the bottom.
private class LessonPickerBottomBar: UIView {
  let startButton = UIButton(type: .system)
  private let countLabel = UILabel()

  var count = 0 {
    didSet { update() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.background.withAlphaComponent(0.96)
    let border = UIView()
    border.backgroundColor = TKMStyle.Color.grey80
    border.translatesAutoresizingMaskIntoConstraints = false
    addSubview(border)

    var config = UIButton.Configuration.filled()
    config.baseBackgroundColor = TKMStyle.Color.accent
    config.baseForegroundColor = .white
    config.cornerStyle = .fixed
    config.background.cornerRadius = 16
    config.image = UIImage(systemName: "arrow.right",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15,
                                                                          weight: .bold))
    config.imagePlacement = .trailing
    config.imagePadding = 8
    config.contentInsets = .init(top: 0, leading: 26, bottom: 0, trailing: 26)
    config.attributedTitle = AttributedString("Start lessons", attributes: AttributeContainer([
      .font: UIFont.systemFont(ofSize: 16, weight: .bold),
    ]))
    startButton.configuration = config
    startButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(startButton)

    countLabel.translatesAutoresizingMaskIntoConstraints = false
    countLabel.adjustsFontForContentSizeCategory = true
    addSubview(countLabel)

    NSLayoutConstraint.activate([
      border.topAnchor.constraint(equalTo: topAnchor),
      border.leadingAnchor.constraint(equalTo: leadingAnchor),
      border.trailingAnchor.constraint(equalTo: trailingAnchor),
      border.heightAnchor.constraint(equalToConstant: 1),
      startButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
      startButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      startButton.heightAnchor.constraint(equalToConstant: 54),
      startButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      countLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      countLabel.trailingAnchor.constraint(lessThanOrEqualTo: startButton.leadingAnchor,
                                           constant: -12),
      countLabel.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
    ])
    update()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func update() {
    startButton.isEnabled = count > 0
    let text = NSMutableAttributedString()
    if count == 0 {
      text.append(NSAttributedString(string: "Tap to select", attributes: [
        .font: UIFont.systemFont(ofSize: 15),
        .foregroundColor: TKMStyle.Color.grey33,
      ]))
    } else {
      text.append(NSAttributedString(string: "\(count)", attributes: [
        .font: UIFont.systemFont(ofSize: 20, weight: .black),
        .foregroundColor: TKMStyle.Color.label,
      ]))
      text.append(NSAttributedString(string: " selected", attributes: [
        .font: UIFont.systemFont(ofSize: 15),
        .foregroundColor: TKMStyle.Color.grey33,
      ]))
    }
    countLabel.attributedText = text
    countLabel.accessibilityLabel = count == 0 ? "No lessons selected" : "\(count) selected"
  }
}
