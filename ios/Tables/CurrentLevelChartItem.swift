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
import WaniKaniAPI

// How far through a level each subject type is, as one stacked bar per type:
// Guru and above, then Apprentice, then available lessons, then locked. Tapping the chart makes
// the bars taller and shows the count in each segment.
class CurrentLevelChartItem: TableModelItem {
  let currentLevelAssignments: [TKMAssignment]

  init(currentLevelAssignments: [TKMAssignment]) {
    self.currentLevelAssignments = currentLevelAssignments
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: CurrentLevelChartCell.self)
  }

  var rowHeight: CGFloat? {
    Settings.expandLevelGraphs ? 174 : 150
  }
}

struct LevelProgress {
  var guru = 0
  var apprentice = 0
  var lesson = 0
  var locked = 0

  var total: Int { guru + apprentice + lesson + locked }

  init(subjectType: TKMSubject.TypeEnum, assignments: [TKMAssignment]) {
    for assignment in assignments {
      if !assignment.hasSubjectType || assignment.subjectType != subjectType {
        continue
      }
      if assignment.isLessonStage {
        lesson += 1
      } else if !assignment.hasSrsStageNumber {
        locked += 1
      } else if assignment.srsStage < .guru1 {
        apprentice += 1
      } else {
        guru += 1
      }
    }
  }
}

class CurrentLevelChartCell: TableModelCell {
  @TypedModelItem var item: CurrentLevelChartItem

  private let rows = [
    LevelProgressRow(title: "Radicals", color: TKMStyle.radicalColor1),
    LevelProgressRow(title: "Kanji", color: TKMStyle.kanjiColor1),
    LevelProgressRow(title: "Vocabulary", color: TKMStyle.vocabularyColor1),
  ]

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    let stack = UIStackView(arrangedSubviews: rows)
    stack.axis = .vertical
    stack.distribution = .fillEqually
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: margins.topAnchor),
      stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
    ])

    contentView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                            action: #selector(didTap)))
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    let assignments = item.currentLevelAssignments
    rows[0].progress = LevelProgress(subjectType: .radical, assignments: assignments)
    rows[1].progress = LevelProgress(subjectType: .kanji, assignments: assignments)
    rows[2].progress = LevelProgress(subjectType: .vocabulary, assignments: assignments)
    updateExpanded()
  }

  private func updateExpanded() {
    for row in rows {
      row.isExpanded = Settings.expandLevelGraphs
    }
  }

  @objc private func didTap() {
    Settings.expandLevelGraphs.toggle()
    let cells = tableView?.visibleCells.compactMap { $0 as? CurrentLevelChartCell } ?? [self]
    UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85,
                   initialSpringVelocity: 0, options: [.beginFromCurrentState]) {
      self.tableView?.performBatchUpdates(nil)
      for cell in cells {
        cell.updateExpanded()
        cell.layoutIfNeeded()
      }
    }
  }
}

private class LevelProgressRow: UIView {
  var progress = LevelProgress(subjectType: .radical, assignments: []) {
    didSet { updateProgress() }
  }

  var isExpanded = false {
    didSet {
      barHeight.constant = isExpanded ? 16 : 8
      bar.showsCounts = isExpanded
    }
  }

  private let color: UIColor
  private let titleLabel = UILabel()
  private let countLabel = UILabel()
  private let bar: LevelProgressBar
  private let barHeight: NSLayoutConstraint

  init(title: String, color: UIColor) {
    self.color = color
    bar = LevelProgressBar(color: color)
    barHeight = bar.heightAnchor.constraint(equalToConstant: 8)
    super.init(frame: .zero)

    let swatch = UIView()
    swatch.backgroundColor = color
    swatch.layer.cornerRadius = 3
    titleLabel.text = title
    titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
    titleLabel.textColor = TKMStyle.Color.label
    countLabel.font = UIFont.systemFont(ofSize: 13)
    countLabel.textColor = TKMStyle.Color.grey33
    countLabel.textAlignment = .right

    for view in [swatch, titleLabel, countLabel, bar] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      swatch.leadingAnchor.constraint(equalTo: leadingAnchor),
      swatch.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
      swatch.widthAnchor.constraint(equalToConstant: 10),
      swatch.heightAnchor.constraint(equalToConstant: 10),
      titleLabel.topAnchor.constraint(equalTo: topAnchor),
      titleLabel.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 8),
      countLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
      countLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
      countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,
                                          constant: 8),
      bar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
      bar.leadingAnchor.constraint(equalTo: leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: trailingAnchor),
      barHeight,
    ])

    isAccessibilityElement = true
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func updateProgress() {
    countLabel.text = "\(progress.guru) of \(progress.total) at Guru"
    bar.progress = progress
    accessibilityLabel = "\(titleLabel.text ?? ""): \(progress.guru) of \(progress.total) " +
      "at Guru, \(progress.apprentice) in Apprentice, \(progress.lesson) in lessons, " +
      "\(progress.locked) locked"
  }
}

private class LevelProgressBar: UIView {
  var progress = LevelProgress(subjectType: .radical, assignments: []) {
    didSet {
      for (label, count) in zip(countLabels, counts) {
        label.text = "\(count)"
      }
      setNeedsLayout()
    }
  }

  var showsCounts = false {
    didSet { setNeedsLayout() }
  }

  // Guru, Apprentice, lessons and locked.
  private let segments: [UIView]
  private let countLabels: [UILabel]

  private var counts: [Int] {
    [progress.guru, progress.apprentice, progress.lesson, progress.locked]
  }

  init(color: UIColor) {
    segments = [color, color.withAlphaComponent(0.45), TKMStyle.Color.grey66,
                TKMStyle.Color.grey80].map {
      let view = UIView()
      view.backgroundColor = $0
      return view
    }
    countLabels = [.white, TKMStyle.Color.label, TKMStyle.Color.label, TKMStyle.Color.grey33].map {
      let label = UILabel()
      label.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
      label.textColor = $0
      label.alpha = 0
      return label
    }
    super.init(frame: .zero)
    clipsToBounds = true
    for view in segments + countLabels {
      addSubview(view)
    }
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2

    // An empty level is drawn as all locked.
    let counts = progress.total > 0 ? self.counts : [0, 0, 0, 1]
    let total = CGFloat(counts.reduce(0, +))
    var x: CGFloat = 0
    for (index, count) in counts.enumerated() {
      let width = bounds.width * CGFloat(count) / total
      let rect = CGRect(x: x, y: 0, width: width, height: bounds.height)
      segments[index].frame = rect

      // Centre the count in its segment, and only show it if it fits.
      let label = countLabels[index]
      let size = label.intrinsicContentSize
      label.bounds = CGRect(origin: .zero, size: size)
      label.center = CGPoint(x: rect.midX, y: rect.midY)
      label.alpha = showsCounts && progress.total > 0 && size.width + 4 <= width ? 1 : 0
      x += width
    }
  }
}
