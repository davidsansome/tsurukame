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

// The top of the home screen: a compact night-indigo Reviews card (or a one-line "all caught
// up" row when nothing is due), with a Lessons card beneath it that can start lessons or open
// the lesson picker.
class HomeHeroItem: TableModelItem {
  let reviewCount: Int
  let lessonCount: Int
  // Shown instead of the lesson count's caption when lessons can't be started.
  let lessonsDisabledMessage: String?
  // When the next reviews become available, and how many, if any are due in the forecast.
  let nextReviewDate: Date?
  let nextReviewCount: Int

  var startReviews: (() -> Void)?
  var startLessons: (() -> Void)?
  var showLessonPicker: (() -> Void)?

  init(reviewCount: Int, lessonCount: Int, lessonsDisabledMessage: String?,
       upcomingReviews: [Int], date: Date) {
    self.reviewCount = reviewCount
    self.lessonCount = lessonCount
    self.lessonsDisabledMessage = lessonsDisabledMessage

    // upcomingReviews[i] is the number of reviews that become available in the hour starting
    // i + 1 hours after the start of the current hour.
    if let index = upcomingReviews.firstIndex(where: { $0 > 0 }) {
      let startOfHour = Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date
      nextReviewDate = startOfHour.addingTimeInterval(Double(index + 1) * 3600)
      nextReviewCount = upcomingReviews[index]
    } else {
      nextReviewDate = nil
      nextReviewCount = 0
    }
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: HomeHeroCell.self)
  }
}

private let kCardSpacing: CGFloat = 12
private let kReviewsCardHeight: CGFloat = 96
private let kCaughtUpRowHeight: CGFloat = 64
private let kLessonsCardHeight: CGFloat = 88
private let kButtonHeight: CGFloat = 44

private func arrowImage(pointSize: CGFloat) -> UIImage? {
  UIImage(systemName: "arrow.right",
          withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold))
}

private func captionText(_ text: String, color: UIColor) -> NSAttributedString {
  NSAttributedString(string: text, attributes: [
    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
    .foregroundColor: color,
    .kern: 2,
  ])
}

class HomeHeroCell: TableModelCell {
  @TypedModelItem var item: HomeHeroItem

  private let reviewsCard = HomeReviewsCard()
  private let caughtUpRow = HomeCaughtUpRow()
  private let lessonsCard = HomeLessonsCard()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    reviewsCard.addAction(UIAction { [weak self] _ in self?.item.startReviews?() },
                          for: .touchUpInside)
    lessonsCard.startButton.addAction(UIAction { [weak self] _ in self?.item.startLessons?() },
                                      for: .touchUpInside)
    lessonsCard.pickButton.addAction(UIAction { [weak self] _ in self?.item.showLessonPicker?() },
                                     for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [reviewsCard, caughtUpRow, lessonsCard])
    stack.axis = .vertical
    stack.spacing = kCardSpacing
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
      reviewsCard.heightAnchor.constraint(equalToConstant: kReviewsCardHeight),
      caughtUpRow.heightAnchor.constraint(equalToConstant: kCaughtUpRowHeight),
      lessonsCard.heightAnchor.constraint(equalToConstant: kLessonsCardHeight),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    // The cards draw their own backgrounds; the row itself is transparent.
    backgroundConfiguration = UIBackgroundConfiguration.clear()

    let hasReviews = item.reviewCount > 0
    reviewsCard.isHidden = !hasReviews
    caughtUpRow.isHidden = hasReviews
    reviewsCard.count = item.reviewCount
    caughtUpRow.setNextReview(date: item.nextReviewDate, count: item.nextReviewCount)

    lessonsCard.count = item.lessonCount
    lessonsCard.detail = item.lessonsDisabledMessage ?? "ready"
    lessonsCard.setEnabled(item.lessonCount > 0 && item.lessonsDisabledMessage == nil)
  }
}

// The night-indigo card with the number of reviews available and a Start pill. The whole card
// is one button.
private class HomeReviewsCard: UIControl {
  var count = 0 {
    didSet {
      countLabel.text = "\(count)"
      accessibilityLabel = "Start \(count) reviews"
    }
  }

  private let captionLabel = UILabel()
  private let countLabel = UILabel()
  private let readyLabel = UILabel()
  private let startPill = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.night
    layer.cornerRadius = 22
    layer.cornerCurve = .continuous
    isAccessibilityElement = true
    accessibilityTraits = .button

    captionLabel.attributedText = captionText("REVIEWS", color: TKMStyle.Color.onNightSecondary)
    countLabel.font = UIFont.systemFont(ofSize: 44, weight: .heavy)
    countLabel.textColor = TKMStyle.Color.onNight
    readyLabel.text = "ready now"
    readyLabel.font = UIFont.systemFont(ofSize: 15)
    readyLabel.textColor = TKMStyle.Color.onNightSecondary

    let countRow = UIStackView(arrangedSubviews: [countLabel, readyLabel])
    countRow.alignment = .firstBaseline
    countRow.spacing = 8
    let text = UIStackView(arrangedSubviews: [captionLabel, countRow])
    text.axis = .vertical
    text.alignment = .leading

    startPill.backgroundColor = TKMStyle.Color.onNight
    startPill.layer.cornerRadius = 12
    startPill.layer.cornerCurve = .continuous
    let startLabel = UILabel()
    startLabel.text = "Start"
    startLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
    startLabel.textColor = TKMStyle.Color.night
    let arrow = UIImageView(image: arrowImage(pointSize: 14))
    arrow.tintColor = TKMStyle.Color.night
    let pillContent = UIStackView(arrangedSubviews: [startLabel, arrow])
    pillContent.alignment = .center
    pillContent.spacing = 6
    pillContent.translatesAutoresizingMaskIntoConstraints = false
    startPill.addSubview(pillContent)

    for view in [text, startPill] {
      view.translatesAutoresizingMaskIntoConstraints = false
      view.isUserInteractionEnabled = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
      text.centerYAnchor.constraint(equalTo: centerYAnchor),
      text.trailingAnchor.constraint(lessThanOrEqualTo: startPill.leadingAnchor, constant: -12),
      startPill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      startPill.centerYAnchor.constraint(equalTo: centerYAnchor),
      startPill.heightAnchor.constraint(equalToConstant: kButtonHeight),
      pillContent.leadingAnchor.constraint(equalTo: startPill.leadingAnchor, constant: 16),
      pillContent.trailingAnchor.constraint(equalTo: startPill.trailingAnchor, constant: -16),
      pillContent.centerYAnchor.constraint(equalTo: startPill.centerYAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isHighlighted: Bool {
    didSet {
      UIView.animate(withDuration: 0.15) {
        self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
      }
    }
  }
}

// A paper row shown in place of the Reviews card when no reviews are available, saying when
// the next ones are due.
private class HomeCaughtUpRow: UIView {
  private let iconCircle = UIView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()

  private let formatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("ha")
    return f
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = 22
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    isAccessibilityElement = true

    iconCircle.backgroundColor = TKMStyle.Color.night
    iconCircle.layer.cornerRadius = 18
    let icon = UIImageView(image: UIImage(systemName: "checkmark",
                                          withConfiguration: UIImage
                                            .SymbolConfiguration(pointSize: 14, weight: .bold)))
    icon.tintColor = TKMStyle.Color.onNight
    icon.translatesAutoresizingMaskIntoConstraints = false
    iconCircle.addSubview(icon)

    titleLabel.text = "All caught up on reviews"
    titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
    titleLabel.textColor = TKMStyle.Color.label
    subtitleLabel.font = UIFont.systemFont(ofSize: 13)
    subtitleLabel.textColor = TKMStyle.Color.grey33
    subtitleLabel.adjustsFontSizeToFitWidth = true
    subtitleLabel.minimumScaleFactor = 0.8

    let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    text.axis = .vertical
    text.spacing = 1

    for view in [iconCircle, text] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      iconCircle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      iconCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconCircle.widthAnchor.constraint(equalToConstant: 36),
      iconCircle.heightAnchor.constraint(equalToConstant: 36),
      icon.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
      text.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 12),
      text.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
      text.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    updateColors()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setNextReview(date: Date?, count: Int) {
    if let date = date {
      let items = count == 1 ? "1 item" : "\(count) items"
      subtitleLabel.text = "Next review at \(formatter.string(from: date)) (\(items))"
    } else {
      subtitleLabel.text = "No reviews in the next few days"
    }
    accessibilityLabel = "\(titleLabel.text!). \(subtitleLabel.text!)"
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColors()
  }

  private func updateColors() {
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }
}

// A paper card with the number of lessons available, a Pick button that opens the lesson
// picker and a Start button that starts lessons.
private class HomeLessonsCard: UIView {
  let pickButton = UIButton(type: .system)
  let startButton = UIButton(type: .system)

  var count = 0 {
    didSet {
      countLabel.text = "\(count)"
      updateAccessibility()
    }
  }

  var detail = "" {
    didSet {
      detailLabel.text = detail
      updateAccessibility()
    }
  }

  private let captionLabel = UILabel()
  private let countLabel = UILabel()
  private let detailLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = 22
    layer.cornerCurve = .continuous
    layer.borderWidth = 1

    captionLabel.attributedText = captionText("LESSONS", color: TKMStyle.Color.grey33)
    countLabel.font = UIFont.systemFont(ofSize: 40, weight: .heavy)
    countLabel.textColor = TKMStyle.Color.label
    detailLabel.font = UIFont.systemFont(ofSize: 15)
    detailLabel.textColor = TKMStyle.Color.grey33
    detailLabel.adjustsFontSizeToFitWidth = true
    detailLabel.minimumScaleFactor = 0.7
    detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let countRow = UIStackView(arrangedSubviews: [countLabel, detailLabel])
    countRow.alignment = .firstBaseline
    countRow.spacing = 8
    let text = UIStackView(arrangedSubviews: [captionLabel, countRow])
    text.axis = .vertical
    text.alignment = .leading
    text.isAccessibilityElement = true
    textAccessibilityElement = text

    var pickConfig = UIButton.Configuration.filled()
    pickConfig.baseBackgroundColor = TKMStyle.Color.background
    pickConfig.baseForegroundColor = TKMStyle.Color.label
    pickConfig.cornerStyle = .fixed
    pickConfig.background.cornerRadius = 12
    pickConfig.background.strokeWidth = 1
    pickConfig.background.strokeColor = TKMStyle.Color.grey80
    pickConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0,
                                                       trailing: 14)
    pickConfig.image = UIImage(systemName: "list.bullet",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13,
                                                                              weight: .semibold))
    pickConfig.imagePadding = 6
    pickConfig.attributedTitle = AttributedString("Pick", attributes: AttributeContainer([
      .font: UIFont.systemFont(ofSize: 15, weight: .bold),
    ]))
    pickButton.configuration = pickConfig
    pickButton.accessibilityLabel = "Lesson picker"
    pickButton.accessibilityHint = "Choose exactly what to learn next"

    var startConfig = UIButton.Configuration.filled()
    startConfig.baseBackgroundColor = TKMStyle.Color.night
    startConfig.baseForegroundColor = TKMStyle.Color.onNight
    startConfig.cornerStyle = .fixed
    startConfig.background.cornerRadius = 12
    startConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0,
                                                        trailing: 14)
    startConfig.image = arrowImage(pointSize: 14)
    startConfig.imagePlacement = .trailing
    startConfig.imagePadding = 6
    startConfig.attributedTitle = AttributedString("Start", attributes: AttributeContainer([
      .font: UIFont.systemFont(ofSize: 16, weight: .bold),
    ]))
    startButton.configuration = startConfig
    startButton.accessibilityLabel = "Start lessons"

    for button in [pickButton, startButton] {
      button.setContentCompressionResistancePriority(.required, for: .horizontal)
      button.setContentHuggingPriority(.required, for: .horizontal)
    }

    let buttons = UIStackView(arrangedSubviews: [pickButton, startButton])
    buttons.spacing = 8

    for view in [text, buttons] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
      text.centerYAnchor.constraint(equalTo: centerYAnchor),
      text.trailingAnchor.constraint(lessThanOrEqualTo: buttons.leadingAnchor, constant: -8),
      buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      buttons.centerYAnchor.constraint(equalTo: centerYAnchor),
      pickButton.heightAnchor.constraint(equalToConstant: kButtonHeight),
      startButton.heightAnchor.constraint(equalToConstant: kButtonHeight),
    ])
    updateColors()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private weak var textAccessibilityElement: UIView?

  func setEnabled(_ enabled: Bool) {
    pickButton.isEnabled = enabled
    startButton.isEnabled = enabled
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColors()
  }

  private func updateColors() {
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }

  private func updateAccessibility() {
    textAccessibilityElement?.accessibilityLabel = "Lessons: \(count), \(detail)"
  }
}
