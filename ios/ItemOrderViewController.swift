// Copyright 2020 David Sansome
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

class ItemOrderCell: UITableViewCell {
  var subjectType: TKMSubject_Type! {
    willSet(subjectType) {
      textLabel!.text = subjectType.name()
    }
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
  }
}

class LessonItemOrderViewController: ItemOrderViewController {
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    hasLessonItemOrder = true
  }
}

class ReviewItemOrderViewController: ItemOrderViewController {
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    hasLessonItemOrder = false
  }
}

class ItemOrderViewController: UITableViewController {
  fileprivate var hasLessonItemOrder: Bool!
  var itemOrder: [Int32] {
    get { hasLessonItemOrder ? Settings.lessonOrder : Settings.reviewItemOrder }
    set(newOrder) {
      if hasLessonItemOrder { Settings.lessonOrder = newOrder }
      else { Settings.reviewItemOrder = newOrder }
    }
  }

  var inOrderCount: Int {
    itemOrder.filter { $0 != TKMSubject_Type.empty.rawValue }.count
  }

  var completeOrder: [Int32] {
    // Correct any error in the actual settings array.
    var newOrder = itemOrder.filter { $0 != TKMSubject_Type.empty.rawValue }
    for _ in newOrder.count ..< itemOrder.count {
      newOrder.append(TKMSubject_Type.empty.rawValue)
    }
    itemOrder = newOrder

    // Compute the actual order array containing all real subject types.
    var order = itemOrder.filter { $0 != TKMSubject_Type.empty.rawValue }
    for type in [TKMSubject_Type.radical, .kanji, .vocabulary] {
      if !order.contains(type.rawValue) { order.append(type.rawValue) }
    }
    return order
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.isEditing = true
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 { return inOrderCount }
    else { return 3 - inOrderCount }
  }

  override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let _cell = tableView.dequeueReusableCell(withIdentifier: "cell") as? ItemOrderCell,
      cell = _cell ?? ItemOrderCell(style: UITableViewCell.CellStyle.default,
                                    reuseIdentifier: "cell")
    if indexPath.section == 0, indexPath.row <= inOrderCount {
      cell.subjectType = TKMSubject_Type(rawValue: completeOrder[indexPath.row])
    } else if indexPath.section > 0, indexPath.row <= 3 - inOrderCount {
      cell.subjectType = TKMSubject_Type(rawValue: completeOrder[inOrderCount + indexPath.row])
    }
    return cell
  }

  override func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) ->
    UITableViewCell.EditingStyle { .none }

  override func tableView(_: UITableView,
                          shouldIndentWhileEditingRowAt _: IndexPath) -> Bool { false }

  override func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool { true }

  override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat { 44 }

  override func tableView(_: UITableView, indentationLevelForRowAt _: IndexPath) -> Int { 0 }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath) {
    let subjectType = (tableView.cellForRow(at: sourceIndexPath) as! ItemOrderCell).subjectType!

    var newOrder: [Int32] = itemOrder
    if sourceIndexPath.section == 0 {
      newOrder.remove(at: sourceIndexPath.row)
      newOrder.append(TKMSubject_Type.empty.rawValue)
    }
    if destinationIndexPath.section == 0 {
      newOrder.removeLast()
      newOrder.insert(subjectType.rawValue, at: destinationIndexPath.row)
    }
    itemOrder = newOrder
  }
}
