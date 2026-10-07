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

// The top of the home screen: a large night-indigo Reviews card over the waves, with smaller
// Lessons and Leeches cards beneath it.
class HomeHeroItem: TableModelItem {
  let reviewCount: Int
  let lessonCount: Int
  // Shown instead of the lesson count's caption when lessons can't be started.
  let lessonsDisabledMessage: String?
  let leechCount: Int

  var startReviews: (() -> Void)?
  var startLessons: (() -> Void)?
  var showLessonPicker: (() -> Void)?
  var startLeechReviews: (() -> Void)?

  init(reviewCount: Int, lessonCount: Int, lessonsDisabledMessage: String?, leechCount: Int) {
    self.reviewCount = reviewCount
    self.lessonCount = lessonCount
    self.lessonsDisabledMessage = lessonsDisabledMessage
    self.leechCount = leechCount
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: HomeHeroCell.self)
  }
}

private let kCardSpacing: CGFloat = 12
private let kReviewsCardHeight: CGFloat = 210
private let kSmallCardHeight: CGFloat = 118

class HomeHeroCell: TableModelCell {
  @TypedModelItem var item: HomeHeroItem

  private let reviewsCard = UIView()
  private let waves = WavesView()
  private let reviewsCaption = UILabel()
  private let reviewsCount = UILabel()
  private let reviewsReady = UILabel()
  private let startReviewsButton = UIButton(type: .system)

  private let lessonsCard = HomeSmallCard()
  private let leechesCard = HomeSmallCard()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    // Reviews card.
    reviewsCard.backgroundColor = TKMStyle.Color.night
    reviewsCard.layer.cornerRadius = 26
    reviewsCard.layer.cornerCurve = .continuous
    reviewsCard.clipsToBounds = true

    reviewsCaption.attributedText = NSAttributedString(string: "REVIEWS", attributes: [
      .font: UIFont.systemFont(ofSize: 12, weight: .bold),
      .foregroundColor: TKMStyle.Color.onNightSecondary,
      .kern: 3,
    ])
    reviewsCount.font = UIFont.systemFont(ofSize: 72, weight: .heavy)
    reviewsCount.textColor = TKMStyle.Color.onNight
    reviewsReady.font = UIFont.systemFont(ofSize: 15)
    reviewsReady.textColor = TKMStyle.Color.onNightSecondary

    var buttonConfig = UIButton.Configuration.filled()
    buttonConfig.baseBackgroundColor = TKMStyle.Color.onNight
    buttonConfig.baseForegroundColor = TKMStyle.Color.night
    buttonConfig.cornerStyle = .fixed
    buttonConfig.background.cornerRadius = 14
    buttonConfig.image = UIImage(systemName: "arrow.right",
                                 withConfiguration: UIImage.SymbolConfiguration(weight: .bold))
    buttonConfig.imagePlacement = .trailing
    buttonConfig.imagePadding = 8
    startReviewsButton.configuration = buttonConfig
    startReviewsButton.addAction(UIAction { [weak self] _ in self?.item.startReviews?() },
                                 for: .touchUpInside)

    let countRow = UIStackView(arrangedSubviews: [reviewsCount, reviewsReady])
    countRow.alignment = .firstBaseline
    countRow.spacing = 10
    let reviewsText = UIStackView(arrangedSubviews: [reviewsCaption, countRow])
    reviewsText.axis = .vertical
    reviewsText.alignment = .leading
    reviewsText.spacing = 0

    let hanko = HankoView()
    hanko.isAccessibilityElement = false
    hanko.transform = CGAffineTransform(rotationAngle: -5 * .pi / 180)

    for view in [waves, reviewsText, startReviewsButton, hanko] {
      view.translatesAutoresizingMaskIntoConstraints = false
      reviewsCard.addSubview(view)
    }

    // Small cards.
    lessonsCard.caption = "LESSONS"
    lessonsCard.addAction(UIAction { [weak self] _ in self?.item.startLessons?() },
                          for: .touchUpInside)
    lessonsCard.accessoryButton.addAction(UIAction { [weak self] _ in
      self?.item.showLessonPicker?()
    }, for: .touchUpInside)
    leechesCard.caption = "LEECHES"
    leechesCard.addAction(UIAction { [weak self] _ in self?.item.startLeechReviews?() },
                          for: .touchUpInside)

    let smallCards = UIStackView(arrangedSubviews: [lessonsCard, leechesCard])
    smallCards.distribution = .fillEqually
    smallCards.spacing = kCardSpacing

    for view in [reviewsCard, smallCards] {
      view.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(view)
    }

    NSLayoutConstraint.activate([
      reviewsCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
      reviewsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      reviewsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      reviewsCard.heightAnchor.constraint(equalToConstant: kReviewsCardHeight),

      waves.leadingAnchor.constraint(equalTo: reviewsCard.leadingAnchor),
      waves.trailingAnchor.constraint(equalTo: reviewsCard.trailingAnchor),
      waves.bottomAnchor.constraint(equalTo: reviewsCard.bottomAnchor),
      waves.heightAnchor.constraint(equalToConstant: 64),

      reviewsText.topAnchor.constraint(equalTo: reviewsCard.topAnchor, constant: 20),
      reviewsText.leadingAnchor.constraint(equalTo: reviewsCard.leadingAnchor, constant: 22),
      reviewsText.trailingAnchor.constraint(lessThanOrEqualTo: reviewsCard.trailingAnchor,
                                            constant: -22),

      hanko.topAnchor.constraint(equalTo: reviewsCard.topAnchor, constant: 22),
      hanko.trailingAnchor.constraint(equalTo: reviewsCard.trailingAnchor, constant: -24),
      hanko.widthAnchor.constraint(equalToConstant: 40),
      hanko.heightAnchor.constraint(equalTo: hanko.widthAnchor, multiplier: HankoView.aspectRatio),

      startReviewsButton.leadingAnchor.constraint(equalTo: reviewsCard.leadingAnchor,
                                                  constant: 20),
      startReviewsButton.trailingAnchor.constraint(equalTo: reviewsCard.trailingAnchor,
                                                   constant: -20),
      startReviewsButton.bottomAnchor.constraint(equalTo: reviewsCard.bottomAnchor,
                                                 constant: -18),
      startReviewsButton.heightAnchor.constraint(equalToConstant: 50),

      smallCards.topAnchor.constraint(equalTo: reviewsCard.bottomAnchor, constant: kCardSpacing),
      smallCards.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      smallCards.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      smallCards.heightAnchor.constraint(equalToConstant: kSmallCardHeight),
      smallCards.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    // The cards draw their own backgrounds; the row itself is transparent.
    backgroundConfiguration = UIBackgroundConfiguration.clear()

    reviewsCount.text = "\(item.reviewCount)"
    let hasReviews = item.reviewCount > 0
    reviewsReady.text = hasReviews ? "ready now" : "all caught up"
    var config = startReviewsButton.configuration
    config?
      .attributedTitle = AttributedString(hasReviews ? "Start reviews" : "No reviews right now",
                                          attributes: AttributeContainer([
                                            .font: UIFont.systemFont(ofSize: 16,
                                                                     weight: .bold),
                                          ]))
    startReviewsButton.configuration = config
    startReviewsButton.isEnabled = hasReviews
    reviewsCard.accessibilityLabel = "\(item.reviewCount) reviews"

    lessonsCard.count = item.lessonCount
    lessonsCard.detail = item.lessonsDisabledMessage ?? "or open the lesson picker"
    lessonsCard.isEnabled = item.lessonCount > 0 && item.lessonsDisabledMessage == nil
    lessonsCard.accessoryButton.isHidden = !lessonsCard.isEnabled
    // The card is a single VoiceOver element, so offer the picker as an action on it.
    lessonsCard.accessibilityCustomActions = lessonsCard.isEnabled ? [
      UIAccessibilityCustomAction(name: "Lesson picker") { [weak self] _ in
        self?.item.showLessonPicker?()
        return true
      },
    ] : nil

    leechesCard.count = item.leechCount
    leechesCard.detail = "in Apprentice"
    leechesCard.isEnabled = item.leechCount > 0
  }
}

// A paper card with a caption, a large count and a line of detail. The whole card is a button.
private class HomeSmallCard: UIControl {
  var caption = "" {
    didSet {
      captionLabel.attributedText = NSAttributedString(string: caption, attributes: [
        .font: UIFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: TKMStyle.Color.grey33,
        .kern: 2,
      ])
      updateAccessibility()
    }
  }

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

  // A small secondary button in the top-right corner (the lesson picker).
  let accessoryButton = UIButton(type: .system)

  private let captionLabel = UILabel()
  private let countLabel = UILabel()
  private let detailLabel = UILabel()
  private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = 22
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    isAccessibilityElement = true
    accessibilityTraits = .button

    countLabel.font = UIFont.systemFont(ofSize: 40, weight: .heavy)
    countLabel.textColor = TKMStyle.Color.label
    detailLabel.font = UIFont.systemFont(ofSize: 13)
    detailLabel.textColor = TKMStyle.Color.grey33
    detailLabel.adjustsFontSizeToFitWidth = true
    detailLabel.minimumScaleFactor = 0.8
    chevron.tintColor = TKMStyle.Color.grey33
    chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13,
                                                                       weight: .semibold)

    accessoryButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
    accessoryButton.tintColor = TKMStyle.Color.label
    accessoryButton.accessibilityLabel = "Lesson picker"
    accessoryButton.isHidden = true

    for view in [captionLabel, countLabel, detailLabel, chevron, accessoryButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
      view.isUserInteractionEnabled = view == accessoryButton
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      captionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      chevron.centerYAnchor.constraint(equalTo: captionLabel.centerYAnchor),
      chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      countLabel.leadingAnchor.constraint(equalTo: captionLabel.leadingAnchor),
      countLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 4),
      detailLabel.leadingAnchor.constraint(equalTo: captionLabel.leadingAnchor),
      detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
      detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
      accessoryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
      accessoryButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
      accessoryButton.widthAnchor.constraint(equalToConstant: 44),
      accessoryButton.heightAnchor.constraint(equalToConstant: 44),
    ])
    updateColors()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isEnabled: Bool {
    didSet {
      alpha = isEnabled ? 1 : 0.55
      chevron.isHidden = !isEnabled
    }
  }

  override var isHighlighted: Bool {
    didSet {
      UIView.animate(withDuration: 0.15) {
        self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
      }
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColors()
  }

  private func updateColors() {
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }

  private func updateAccessibility() {
    accessibilityLabel = "\(caption.capitalized): \(count), \(detail)"
  }
}

// A large night-indigo card for a practice mode on the Practice tab.
class PracticeCardItem: TableModelItem {
  let caption: String
  let title: String
  let glyph: String
  let samples: [String]
  let start: () -> Void

  init(caption: String, title: String, glyph: String, samples: [String],
       start: @escaping () -> Void) {
    self.caption = caption
    self.title = title
    self.glyph = glyph
    self.samples = samples
    self.start = start
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: PracticeCardCell.self)
  }
}

class PracticeCardCell: TableModelCell {
  @TypedModelItem var item: PracticeCardItem

  private let card = UIView()
  private let captionLabel = UILabel()
  private let titleLabel = UILabel()
  private let glyphLabel = UILabel()
  private let samplesStack = UIStackView()
  private let startButton = UIButton(type: .system)

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none

    card.backgroundColor = TKMStyle.Color.night
    card.layer.cornerRadius = 26
    card.layer.cornerCurve = .continuous
    card.clipsToBounds = true

    let waves = WavesView()
    titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .heavy)
    titleLabel.textColor = TKMStyle.Color.onNight
    titleLabel.numberOfLines = 2
    // Subjects and kana always use the app's Japanese font.
    glyphLabel.font = UIFont(name: TKMStyle.japaneseFontName, size: 104)
    glyphLabel.textColor = TKMStyle.Color.onNight
    glyphLabel.isAccessibilityElement = false
    // The glyph keeps its size; a long title wraps instead.
    glyphLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    glyphLabel.setContentHuggingPriority(.required, for: .horizontal)
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    samplesStack.spacing = 6
    samplesStack.isAccessibilityElement = false

    var config = UIButton.Configuration.filled()
    config.baseBackgroundColor = TKMStyle.Color.onNight
    config.baseForegroundColor = TKMStyle.Color.night
    config.cornerStyle = .fixed
    config.background.cornerRadius = 14
    config.image = UIImage(systemName: "arrow.right",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .bold))
    config.imagePlacement = .trailing
    config.imagePadding = 8
    config.attributedTitle = AttributedString("Start practice", attributes: AttributeContainer([
      .font: UIFont.systemFont(ofSize: 16, weight: .bold),
    ]))
    startButton.configuration = config
    startButton.addAction(UIAction { [weak self] _ in self?.item.start() }, for: .touchUpInside)

    for view in [waves, glyphLabel, captionLabel, titleLabel, samplesStack, startButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
      card.addSubview(view)
    }
    card.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(card)

    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
      card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
      card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      card.heightAnchor.constraint(equalToConstant: 290),

      waves.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      waves.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      waves.bottomAnchor.constraint(equalTo: card.bottomAnchor),
      waves.heightAnchor.constraint(equalToConstant: 100),

      glyphLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
      glyphLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

      captionLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
      captionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
      titleLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 4),
      titleLabel.leadingAnchor.constraint(equalTo: captionLabel.leadingAnchor),
      titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: glyphLabel.leadingAnchor,
                                           constant: -8),

      samplesStack.leadingAnchor.constraint(equalTo: captionLabel.leadingAnchor),
      samplesStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),

      startButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
      startButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
      startButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
      startButton.heightAnchor.constraint(equalToConstant: 50),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    backgroundConfiguration = UIBackgroundConfiguration.clear()
    captionLabel.attributedText = NSAttributedString(string: item.caption.uppercased(),
                                                     attributes: [
                                                       .font: UIFont.systemFont(ofSize: 12,
                                                                                weight: .bold),
                                                       .foregroundColor: TKMStyle.Color
                                                         .onNightSecondary,
                                                       .kern: 3,
                                                     ])
    titleLabel.text = item.title
    glyphLabel.text = item.glyph
    startButton.accessibilityLabel = "Start \(item.title) practice"

    samplesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for sample in item.samples {
      let label = UILabel()
      label.text = sample
      label.font = UIFont(name: TKMStyle.japaneseFontName, size: 18)
      label.textColor = TKMStyle.Color.onNight
      label.textAlignment = .center
      label.backgroundColor = TKMStyle.Color.onNight.withAlphaComponent(0.12)
      label.layer.cornerRadius = 9
      label.clipsToBounds = true
      label.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        label.widthAnchor.constraint(equalToConstant: 34),
        label.heightAnchor.constraint(equalToConstant: 34),
      ])
      samplesStack.addArrangedSubview(label)
    }
  }
}

// Where users can tell us what they think of the redesign.
let kRedesignFeedbackURL =
  URL(string: "https://github.com/davidsansome/tsurukame/issues/new?title=Visual%20redesign%20feedback")!

// A one-line card at the top of the home screen asking for feedback on the redesign, with a close
// button to dismiss it.
class RedesignFeedbackItem: TableModelItem {
  let close: () -> Void

  init(close: @escaping () -> Void) {
    self.close = close
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: RedesignFeedbackCell.self)
  }
}

class RedesignFeedbackCell: TableModelCell {
  @TypedModelItem var item: RedesignFeedbackItem

  private let card = RedesignFeedbackCard()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    // Shares a section with the hero cards, but shouldn't draw a separator above them.
    separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)

    card.addAction(UIAction { _ in UIApplication.shared.open(kRedesignFeedbackURL) },
                   for: .touchUpInside)
    card.closeButton.addAction(UIAction { [weak self] _ in self?.item.close() },
                               for: .touchUpInside)

    card.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(card)
    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
      card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
      card.heightAnchor.constraint(equalToConstant: 48),
    ])
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    // The card draws its own background; the row itself is transparent.
    backgroundConfiguration = UIBackgroundConfiguration.clear()
  }
}

// A paper card with an icon, a line of text and a close button. The whole card is a button.
private class RedesignFeedbackCard: UIControl {
  let closeButton = UIButton(type: .system)

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = 16
    layer.cornerCurve = .continuous
    layer.borderWidth = 1

    let icon = UIImageView(image: UIImage(systemName: "bubble.left.and.text.bubble.right"))
    icon.tintColor = TKMStyle.Color.accent
    icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15,
                                                                    weight: .semibold)
    icon.setContentHuggingPriority(.required, for: .horizontal)

    let label = UILabel()
    label.text = "Give feedback on the new app look"
    label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    label.textColor = TKMStyle.Color.label
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8

    closeButton.setImage(UIImage(systemName: "xmark",
                                 withConfiguration: UIImage
                                   .SymbolConfiguration(pointSize: 13, weight: .semibold)),
                         for: .normal)
    closeButton.tintColor = TKMStyle.Color.grey33
    closeButton.accessibilityLabel = "Dismiss"

    for view in [icon, label, closeButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
      view.isUserInteractionEnabled = view == closeButton
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      icon.centerYAnchor.constraint(equalTo: centerYAnchor),
      label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
      label.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),
      closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
    ])

    // The card is a single VoiceOver element, so offer dismissing as an action on it.
    isAccessibilityElement = true
    accessibilityTraits = .link
    accessibilityLabel = label.text
    accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Dismiss") { [weak self] _ in
        self?.closeButton.sendActions(for: .touchUpInside)
        return true
      },
    ]
    updateColors()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isHighlighted: Bool {
    didSet {
      UIView.animate(withDuration: 0.15) {
        self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
      }
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateColors()
  }

  private func updateColors() {
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }
}
