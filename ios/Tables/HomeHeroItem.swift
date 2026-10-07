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
