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

class SRSStageCategoryItem: BasicModelItem {
  let stageCategory: SRSStageCategory

  init(stageCategory: SRSStageCategory, count: Int,
       accessoryType: UITableViewCell.AccessoryType = .none) {
    self.stageCategory = stageCategory
    super.init(style: .value1,
               title: stageCategory.description,
               subtitle: String(count),
               accessoryType: accessoryType)

    let color = TKMStyle.color(forSRSStageCategory: stageCategory)
    textColor = color
    imageTintColor = color
    image = UIImage(named: stageCategory.description)!
  }
}

// One stacked bar across all SRS stages, shown above the per-stage rows. Every non-empty stage
// gets at least a sliver so small counts stay visible next to hundreds of burned items.
class SRSBreakdownItem: TableModelItem {
  let counts: [SRSStageCategory: Int]

  init(counts: [SRSStageCategory: Int]) {
    self.counts = counts
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: SRSBreakdownCell.self)
  }

  var rowHeight: CGFloat? { 38 }
}

class SRSBreakdownCell: TableModelCell {
  @TypedModelItem var item: SRSBreakdownItem

  private let stack = UIStackView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    stack.spacing = 2
    stack.layer.cornerRadius = 5
    stack.clipsToBounds = true
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    let margins = contentView.layoutMarginsGuide
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
      stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      stack.heightAnchor.constraint(equalToConstant: 10),
    ])
    isAccessibilityElement = false
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func update() {
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let total = item.counts.values.reduce(0, +)
    guard total > 0 else { return }

    var segments = [UIView]()
    for category in SRSStageCategory.apprentice ... SRSStageCategory.burned {
      let count = item.counts[category] ?? 0
      if count == 0 { continue }
      let segment = UIView()
      segment.backgroundColor = TKMStyle.color(forSRSStageCategory: category)
      segment.translatesAutoresizingMaskIntoConstraints = false
      stack.addArrangedSubview(segment)
      segment.widthAnchor.constraint(greaterThanOrEqualToConstant: 6).isActive = true
      if let first = segments.first {
        let ratio = CGFloat(count) / CGFloat(item.counts[categoryOf(first)] ?? 1)
        let c = segment.widthAnchor.constraint(equalTo: first.widthAnchor, multiplier: ratio)
        c.priority = .defaultHigh
        c.isActive = true
      }
      segment.tag = category.rawValue
      segments.append(segment)
    }
  }

  private func categoryOf(_ view: UIView) -> SRSStageCategory {
    SRSStageCategory(rawValue: view.tag)!
  }
}
