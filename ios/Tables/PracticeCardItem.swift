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
