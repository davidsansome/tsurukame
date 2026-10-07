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

// A subject in a list of subjects: a tile in its colour, its meaning and reading, and its SRS
// stage's symbol (or a chip for lessons, locked subjects and search results). Used by the level,
// SRS stage, excluded and search lists.
class SubjectListItem: TableModelItem {
  enum Detail {
    // Just the SRS stage.
    case stage
    // The SRS stage and what happens next on the way to Guru: a review, a lesson, or unlocking.
    case remaining
  }

  let subject: TKMSubject
  let assignment: TKMAssignment?
  weak var delegate: SubjectDelegate?
  var detail = Detail.stage
  var showAnswers = true

  init(subject: TKMSubject, assignment: TKMAssignment?, delegate: SubjectDelegate) {
    self.subject = subject
    self.assignment = assignment
    self.delegate = delegate
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: SubjectListCell.self)
  }
}

// Shows or hides the answers on every SubjectListItem in the model.
func setSubjectListAnswersShown(_ showAnswers: Bool, model: TableModel?, tableView: UITableView,
                                animated: Bool) {
  guard let model = model else { return }
  for section in 0 ..< model.sectionCount {
    for case let item as SubjectListItem in model.items(inSection: section) {
      item.showAnswers = showAnswers
    }
  }
  for case let cell as SubjectListCell in tableView.visibleCells {
    cell.setShowAnswers(showAnswers, animated: animated)
  }
}

class SubjectListCell: TableModelCell {
  @TypedModelItem var item: SubjectListItem

  private let tile = UIView()
  private let japaneseLabel = UILabel()
  private let meaningLabel = UILabel()
  private let readingLabel = UILabel()
  private let answers = UIStackView()
  // Stand-ins for the meaning and reading while answers are hidden.
  private let placeholders = UIStackView()
  private let meaningPlaceholder = UIView()
  private let readingPlaceholder = UIView()
  private var meaningPlaceholderWidth: NSLayoutConstraint!
  private let chip = PillLabel()
  // Subjects in an SRS stage get the stage's symbol in a small circle instead of a chip, so it fits
  // next to long meanings. The same symbols are used on the home screen.
  private let stageBadge = UIImageView()
  private var stageDescription: String?
  private let stageBadgeBackground = UIView()
  private let whenLabel = UILabel()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    tile.layer.cornerRadius = 12
    tile.layer.cornerCurve = .continuous
    japaneseLabel.font = UIFont(name: TKMStyle.japaneseFontName, size: 22)
    japaneseLabel.textColor = .white
    japaneseLabel.textAlignment = .center
    japaneseLabel.translatesAutoresizingMaskIntoConstraints = false
    tile.addSubview(japaneseLabel)

    meaningLabel.font = UIFontMetrics(forTextStyle: .body)
      .scaledFont(for: UIFont.systemFont(ofSize: 15, weight: .medium))
    meaningLabel.textColor = TKMStyle.Color.label
    readingLabel.font = UIFont(name: TKMStyle.japaneseFontName, size: 13)
    readingLabel.textColor = TKMStyle.Color.grey33
    answers.addArrangedSubview(meaningLabel)
    answers.addArrangedSubview(readingLabel)
    answers.axis = .vertical
    answers.spacing = 3

    for (bar, height) in [(meaningPlaceholder, 12.0), (readingPlaceholder, 10.0)] {
      bar.backgroundColor = TKMStyle.Color.separator
      bar.layer.cornerRadius = height / 2
      bar.heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    meaningPlaceholderWidth = meaningPlaceholder.widthAnchor.constraint(equalToConstant: 48)
    meaningPlaceholderWidth.isActive = true
    readingPlaceholder.widthAnchor.constraint(equalToConstant: 56).isActive = true
    placeholders.addArrangedSubview(meaningPlaceholder)
    placeholders.addArrangedSubview(readingPlaceholder)
    placeholders.axis = .vertical
    placeholders.alignment = .leading
    placeholders.spacing = 6

    let text = UIStackView(arrangedSubviews: [answers, placeholders])
    text.axis = .vertical

    chip.font = UIFont.systemFont(ofSize: 11, weight: .bold)
    chip.insets = UIEdgeInsets(top: 4, left: 9, bottom: 4, right: 9)
    whenLabel.font = UIFont.systemFont(ofSize: 12)
    stageBadge.contentMode = .scaleAspectFit
    stageBadge.translatesAutoresizingMaskIntoConstraints = false
    stageBadgeBackground.layer.cornerRadius = 13
    stageBadgeBackground.addSubview(stageBadge)
    let trailing = UIStackView(arrangedSubviews: [chip, stageBadgeBackground, whenLabel])
    trailing.axis = .vertical
    trailing.alignment = .trailing
    trailing.spacing = 4

    let row = UIStackView(arrangedSubviews: [tile, text, trailing])
    row.alignment = .center
    row.spacing = 12
    row.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(row)

    // The tile, chip and badge never shrink; a long meaning is truncated instead.
    for view in [tile, trailing, chip, stageBadgeBackground, whenLabel] {
      view.setContentHuggingPriority(.required, for: .horizontal)
      view.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    for label in [meaningLabel, readingLabel] {
      label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    japaneseLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    let minimumHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
    minimumHeight.priority = .defaultHigh
    NSLayoutConstraint.activate([
      minimumHeight,
      tile.heightAnchor.constraint(equalToConstant: 44),
      stageBadgeBackground.widthAnchor.constraint(equalToConstant: 26),
      stageBadgeBackground.heightAnchor.constraint(equalToConstant: 26),
      stageBadge.centerXAnchor.constraint(equalTo: stageBadgeBackground.centerXAnchor),
      stageBadge.centerYAnchor.constraint(equalTo: stageBadgeBackground.centerYAnchor),
      stageBadge.widthAnchor.constraint(equalToConstant: 24),
      stageBadge.heightAnchor.constraint(equalToConstant: 24),
      tile.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
      japaneseLabel.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
      japaneseLabel.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 8),
      japaneseLabel.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -8),
      row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
      row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    let subject = item.subject
    japaneseLabel.attributedText = japaneseText(subject, imageSize: 22)

    let meaning = subject.commaSeparatedMeanings(showOldMnemonic: Settings.showOldMnemonic)
    meaningLabel.text = meaning
    switch subject.subjectType {
    case .kanji:
      readingLabel.text = subject.commaSeparatedPrimaryReadings
    case .vocabulary:
      readingLabel.text = subject.commaSeparatedReadings
    default:
      readingLabel.text = nil
    }
    readingLabel.isHidden = (readingLabel.text ?? "").isEmpty
    readingPlaceholder.isHidden = readingLabel.isHidden
    meaningPlaceholderWidth.constant = min(150, max(48, CGFloat(meaning.count) * 7))

    updateColors()
    updateWhen()
    setShowAnswers(item.showAnswers, animated: false)

    let stage = stageBadgeBackground.isHidden ? chip.text : stageDescription
    accessibilityLabel = [subject.japanese, item.showAnswers ? meaning : nil, stage,
                          whenLabel.isHidden ? nil : whenLabel.text]
      .compactMap { $0 }.joined(separator: ", ")
    accessibilityTraits = .button
  }

  func setShowAnswers(_ show: Bool, animated: Bool) {
    let change = {
      self.answers.isHidden = !show
      self.placeholders.isHidden = show
    }
    if animated {
      UIView.transition(with: contentView, duration: 0.25, options: .transitionCrossDissolve,
                        animations: change)
    } else {
      change()
    }
  }

  override func didSelect() {
    item.delegate?.didTapSubject(item.subject)
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if baseItem != nil {
      updateColors()
    }
  }

  // The tile is in the subject's colour, except locked subjects are grey and burned ones ink.
  private func updateColors() {
    chip.layer.borderWidth = 0
    chip.isHidden = false
    stageBadgeBackground.isHidden = true
    guard let assignment = item.assignment else {
      // Search results don't have assignments, so show the level instead.
      tile.backgroundColor = TKMStyle.color2(forSubjectType: item.subject.subjectType)
      setChip(text: "Level \(item.subject.level)", color: TKMStyle.Color.grey33,
              background: .clear, border: TKMStyle.Color.grey80)
      return
    }

    if assignment.isLocked {
      tile.backgroundColor = TKMStyle.lockedTileColor
      let lock = UIImage(systemName: "lock.fill",
                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 8,
                                                                        weight: .bold))!
        .withTintColor(TKMStyle.Color.grey33, renderingMode: .alwaysOriginal)
      let text = NSMutableAttributedString(attachment: NSTextAttachment(image: lock))
      text.append(NSAttributedString(string: " Locked"))
      chip.attributedText = text
      chip.textColor = TKMStyle.Color.grey33
      chip.backgroundColor = TKMStyle.Color.separator
    } else if assignment.isLessonStage {
      tile.backgroundColor = TKMStyle.color2(forSubjectType: item.subject.subjectType)
      setChip(text: "Lesson", color: TKMStyle.Color.grey33, background: .clear,
              border: TKMStyle.Color.grey80)
    } else {
      let category = assignment.srsStage.category
      let isBurned = category == .burned
      tile.backgroundColor = isBurned ? TKMStyle.fillColor(forSRSStageCategory: .burned)
        : TKMStyle.color2(forSubjectType: item.subject.subjectType)
      chip.isHidden = true
      stageBadgeBackground.isHidden = false
      stageDescription = assignment.srsStage.description
      stageBadge.image = UIImage(named: category.description)?.withRenderingMode(.alwaysTemplate)
      if isBurned {
        stageBadgeBackground.backgroundColor = TKMStyle.Color.label
        stageBadge.tintColor = TKMStyle.Color.background
      } else {
        // A tint of the stage's colour, like the stage list on the home screen.
        let color = TKMStyle.color(forSRSStageCategory: category)
        stageBadgeBackground.backgroundColor = color.withAlphaComponent(0.14)
        stageBadge.tintColor = color
      }
    }
  }

  private func setChip(text: String, color: UIColor, background: UIColor,
                       border: UIColor? = nil) {
    chip.attributedText = nil
    chip.text = text
    chip.textColor = color
    chip.backgroundColor = background
    if let border = border {
      chip.layer.borderWidth = 1
      chip.layer.borderColor = border.resolvedColor(with: traitCollection).cgColor
    }
  }

  // Under the chip on the remaining list: what's next on the way to Guru. Anything that can be
  // done now is in the accent colour.
  private func updateWhen() {
    guard item.detail == .remaining, let assignment = item.assignment else {
      whenLabel.isHidden = true
      return
    }
    whenLabel.isHidden = false
    var now = false
    if assignment.isLocked {
      switch item.subject.subjectType {
      case .kanji: whenLabel.text = "After its radicals"
      case .vocabulary: whenLabel.text = "After its kanji"
      default: whenLabel.text = "Locked"
      }
    } else if assignment.isLessonStage {
      whenLabel.text = "Available now"
      now = true
    } else if let reviewDate = assignment.reviewDate, reviewDate <= Date() {
      whenLabel.text = "Review now"
      now = true
    } else if let guruDate = assignment.guruDate(subject: item.subject) {
      whenLabel.text = "Guru in ~" + formattedInterval(until: guruDate)
    } else {
      whenLabel.isHidden = true
    }
    whenLabel.textColor = now ? TKMStyle.Color.accent : TKMStyle.Color.grey33
    whenLabel.font = UIFont.systemFont(ofSize: 12, weight: now ? .bold : .regular)
  }

  private func formattedInterval(until date: Date) -> String {
    var components = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(),
                                                     to: date)
    // Only show minutes when there are no hours left.
    if components.hour ?? 0 > 0 || components.day ?? 0 > 0 {
      components.minute = 0
    }
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: components) ?? ""
  }
}

// The "Show answers" pill in the navigation bar of a subject list. Filled in ink while on.
class ShowAnswersButton: UIButton {
  var isOn = false {
    didSet { updateAppearance() }
  }

  var onChange: ((Bool) -> Void)?

  convenience init(isOn: Bool) {
    self.init(type: .system)
    self.isOn = isOn
    addAction(UIAction { [unowned self] _ in
      self.isOn.toggle()
      self.onChange?(self.isOn)
    }, for: .touchUpInside)
    updateAppearance()
  }

  private func updateAppearance() {
    var config = UIButton.Configuration.filled()
    let foreground = isOn ? TKMStyle.Color.background : TKMStyle.Color.label
    config.image = UIImage(systemName: isOn ? "eye" : "eye.slash",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 13,
                                                                          weight: .semibold))?
      .withTintColor(foreground, renderingMode: .alwaysOriginal)
    config.imagePadding = 6
    config.cornerStyle = .capsule
    config.baseBackgroundColor = isOn ? TKMStyle.Color.label : TKMStyle.Color.cellBackground
    config.background.strokeColor = isOn ? .clear : TKMStyle.Color.grey80
    config.background.strokeWidth = 1
    config.baseForegroundColor = foreground
    config.attributedTitle = AttributedString("Show answers", attributes: AttributeContainer([
      .font: UIFont.systemFont(ofSize: 14, weight: .medium),
      .foregroundColor: foreground,
    ]))
    // The navigation bar tints its items' content, which would hide the text on ink.
    tintColor = foreground
    configuration = config
    accessibilityTraits = isOn ? [.button, .selected] : .button
  }
}
