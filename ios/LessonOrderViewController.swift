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

class LessonOrderViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.isEditing = true
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    Settings.lessonOrder.count
  }

  override func tableView(_ tableView: UITableView,
                          cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = (tableView.dequeueReusableCell(withIdentifier: "cell") as? LessonOrderCell) ??
      LessonOrderCell(style: .default, reuseIdentifier: "cell")
    cell.subjectType = Settings.lessonOrder[indexPath.row]
    return cell
  }

  override func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell
    .EditingStyle {
    .none
  }

  override func tableView(_: UITableView, shouldIndentWhileEditingRowAt _: IndexPath) -> Bool {
    false
  }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath,
                          to destinationIndexPath: IndexPath) {
    let cell = tableView.cellForRow(at: sourceIndexPath) as! LessonOrderCell

    var lessonOrder = Settings.lessonOrder
    lessonOrder.remove(at: sourceIndexPath.row)
    lessonOrder.insert(cell.subjectType, at: destinationIndexPath.row)
    Settings.lessonOrder = lessonOrder
  }
}

private class LessonOrderCell: UITableViewCell {
  var subjectType: TKMSubject.TypeEnum = .unknown {
    didSet {
      textLabel?.text = subjectType.description
    }
  }
}
