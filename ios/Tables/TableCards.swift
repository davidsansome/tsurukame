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

// Draws each section's rows on a paper card with a thin border. The system's own grouped
// backgrounds can't be given a border, so the rows are drawn clear over cards laid out here.
// Call prepare() on the table's model, and layout() from viewDidLayoutSubviews.
class TableCards {
  private unowned let tableView: UITableView
  private var cardViews = [CardView]()

  init(tableView: UITableView) {
    self.tableView = tableView
  }

  func prepare(_ model: TableModel) {
    model.cellBackgroundColor = .clear
  }

  func layout() {
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
      let card = CardView()
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

private class CardView: UIView {
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
