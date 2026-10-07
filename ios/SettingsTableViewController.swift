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

private let kCardCornerRadius: CGFloat = 20
private let kLargeTitleSize: CGFloat = 32
private let kMinimumLargeTitleSize: CGFloat = 20

func largeTitleFont(size: CGFloat = kLargeTitleSize) -> UIFont {
  UIFontMetrics(forTextStyle: .largeTitle)
    .scaledFont(for: UIFont.systemFont(ofSize: size, weight: .black))
}

// The settings pages share one look: a large heavy title under the back button, and each section's
// rows on a bordered paper card, in smaller text than the app's other lists.
class SettingsTableViewController: UITableViewController {
  // One card behind each section's rows. The system's own grouped backgrounds can't be given a
  // border, so the rows are drawn clear over these instead.
  private var cardViews = [SettingsCardView]()

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.largeTitleDisplayMode = .always
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    fitLargeTitle()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    layoutCards()
  }

  // Applies the settings fonts and colours to the model's rows. Call before reloading the table.
  func styleRows(_ model: TableModel) {
    model.cellBackgroundColor = .clear
    let titleFont = UIFontMetrics(forTextStyle: .body)
      .scaledFont(for: UIFont.systemFont(ofSize: 15, weight: .medium))
    let valueFont = UIFontMetrics(forTextStyle: .body)
      .scaledFont(for: UIFont.systemFont(ofSize: 15))
    let subtitleFont = UIFontMetrics(forTextStyle: .subheadline)
      .scaledFont(for: UIFont.systemFont(ofSize: 13))

    for section in model.sections {
      for case let item as BasicModelItem in section.items {
        item.titleFont = titleFont
        // A .value1 row's subtitle is its current value, shown on the right.
        item.subtitleFont = item.style == .value1 ? valueFont : subtitleFont
        item.subtitleTextColor = TKMStyle.Color.grey33
      }
    }
  }

  // Large titles don't wrap, so a long one ("Radicals, Kanji & Vocabulary") is set smaller until
  // it fits on one line.
  private func fitLargeTitle() {
    guard let bar = navigationController?.navigationBar,
          let title = navigationItem.title ?? title else {
      return
    }
    let available = bar.bounds.width - bar.layoutMargins.left - bar.layoutMargins.right
    var size = kLargeTitleSize
    while size > kMinimumLargeTitleSize,
          (title as NSString).size(withAttributes: [.font: largeTitleFont(size: size)]).width >
          available {
      size -= 1
    }
    if size == kLargeTitleSize {
      return
    }

    let font = largeTitleFont(size: size)
    let standard = bar.standardAppearance.copy()
    standard.largeTitleTextAttributes[.font] = font
    navigationItem.standardAppearance = standard
    if let scrollEdge = bar.scrollEdgeAppearance?.copy() {
      scrollEdge.largeTitleTextAttributes[.font] = font
      navigationItem.scrollEdgeAppearance = scrollEdge
    }
  }

  private func layoutCards() {
    var frames = [CGRect]()
    for section in 0 ..< tableView.numberOfSections {
      let rows = tableView.numberOfRows(inSection: section)
      if rows == 0 {
        continue
      }
      let first = tableView.rectForRow(at: IndexPath(row: 0, section: section))
      let last = tableView.rectForRow(at: IndexPath(row: rows - 1, section: section))
      frames.append(first.union(last))
    }

    while cardViews.count < frames.count {
      let card = SettingsCardView()
      tableView.insertSubview(card, at: 0)
      cardViews.append(card)
    }
    for (i, card) in cardViews.enumerated() {
      card.isHidden = i >= frames.count
      if i < frames.count {
        card.frame = frames[i]
      }
    }
  }
}

private class SettingsCardView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = TKMStyle.Color.cellBackground
    layer.cornerRadius = kCardCornerRadius
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Resolved here so it follows light and dark mode.
    layer.borderColor = TKMStyle.Color.cardBorder.resolvedColor(with: traitCollection).cgColor
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    setNeedsLayout()
  }
}
