// Copyright 2021 David Sansome
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

class LessonTypeOrderViewController: TypeOrderViewController {
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    hasLessonOrder = true
  }
}

class ReviewTypeOrderViewController: TypeOrderViewController {
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    hasLessonOrder = false
  }
}

class TypeOrderViewController: UITableViewController {
  var hasLessonOrder: Bool!
  var typeOrder: [TKMSubject.TypeEnum] {
    get { hasLessonOrder ? Settings.lessonTypeOrder : Settings.reviewTypeOrder }
    set {
      if hasLessonOrder { Settings.lessonTypeOrder = newValue }
      else { Settings.reviewTypeOrder = newValue }
    }
  }

  var filteredTypeOrder: [TKMSubject.TypeEnum] {
    // Correct any error in the actual settings array.
    var newOrder = typeOrder.filter { $0 != .unknown }
    for _ in newOrder.count ..< typeOrder.count {
      newOrder.append(.unknown)
    }
    typeOrder = newOrder

    return typeOrder.filter { $0 != .unknown }
  }

  var completeTypeOrder: [TKMSubject.TypeEnum] {
    var order = filteredTypeOrder
    for type in [TKMSubject.TypeEnum.radical, .kanji, .vocabulary] {
      if !order.contains(type) { order.append(type) }
    }
    return order
  }

  private func adjustment(_ section: Int) -> Int {
    section == 0 ? 0 : filteredTypeOrder.count
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.isEditing = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 { return filteredTypeOrder.count }
    else { return 3 - filteredTypeOrder.count }
  }

  override func tableView(_ tableView: UITableView,
                          cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = (tableView.dequeueReusableCell(withIdentifier: "cell") as? TypeOrderCell) ??
      TypeOrderCell(style: .default, reuseIdentifier: "cell")
    cell.subjectType = completeTypeOrder[adjustment(indexPath.section) + indexPath.row]
    return cell
  }

  override func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell
    .EditingStyle {
    .none
  }

  override func tableView(_: UITableView, shouldIndentWhileEditingRowAt _: IndexPath) -> Bool {
    false
  }

  override func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool { true }

  override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat { 44 }

  override func tableView(_: UITableView, indentationLevelForRowAt _: IndexPath) -> Int { 0 }

  override func tableView(_: UITableView, moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath) {
    let type = completeTypeOrder[adjustment(sourceIndexPath.section) + sourceIndexPath.row]

    var order = typeOrder
    if sourceIndexPath.section == 0 {
      order.remove(at: sourceIndexPath.row)
      order.append(.unknown)
    }
    if destinationIndexPath.section == 0 {
      order.removeLast()
      order.insert(type, at: destinationIndexPath.row)
    }
    typeOrder = order
  }
}

private class TypeOrderCell: UITableViewCell {
  var subjectType: TKMSubject.TypeEnum = .unknown {
    didSet {
      textLabel?.text = subjectType.description
    }
  }
}
