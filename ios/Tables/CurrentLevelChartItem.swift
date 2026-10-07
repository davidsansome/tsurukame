// Copyright 2025 David Sansome
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
// Guru and above, then Apprentice, then available lessons, then locked.
class CurrentLevelChartItem: TableModelItem {
  let currentLevelAssignments: [TKMAssignment]

  init(currentLevelAssignments: [TKMAssignment]) {
    self.currentLevelAssignments = currentLevelAssignments
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: CurrentLevelChartCell.self)
  }

  var rowHeight: CGFloat? {
    150
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
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    let assignments = item.currentLevelAssignments
    rows[0].progress = LevelProgress(subjectType: .radical, assignments: assignments)
    rows[1].progress = LevelProgress(subjectType: .kanji, assignments: assignments)
    rows[2].progress = LevelProgress(subjectType: .vocabulary, assignments: assignments)
  }
}

private class LevelProgressRow: UIView {
  var progress = LevelProgress(subjectType: .radical, assignments: []) {
    didSet { updateProgress() }
  }

  private let color: UIColor
  private let titleLabel = UILabel()
  private let countLabel = UILabel()
  private let bar = LevelProgressBar()

  init(title: String, color: UIColor) {
    self.color = color
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
    bar.color = color

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
      bar.heightAnchor.constraint(equalToConstant: 8),
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
  var color = UIColor.gray {
    didSet { setNeedsDisplay() }
  }

  var progress = LevelProgress(subjectType: .radical, assignments: []) {
    didSet { setNeedsDisplay() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = .clear
    contentMode = .redraw
  }

  @available(*, unavailable) required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_: CGRect) {
    let track = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2)
    TKMStyle.Color.grey80.resolvedColor(with: traitCollection).setFill()
    track.fill()
    guard progress.total > 0 else { return }

    track.addClip()
    let base = color.resolvedColor(with: traitCollection)
    let segments: [(Int, UIColor)] = [
      (progress.guru, base),
      (progress.apprentice, base.withAlphaComponent(0.45)),
      (progress.lesson, TKMStyle.Color.grey66.resolvedColor(with: traitCollection)),
    ]
    var x: CGFloat = 0
    for (count, segmentColor) in segments where count > 0 {
      let width = bounds.width * CGFloat(count) / CGFloat(progress.total)
      segmentColor.setFill()
      UIRectFill(CGRect(x: x, y: 0, width: width, height: bounds.height))
      x += width
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    setNeedsDisplay()
  }
}
