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

import UIKit

class InterfaceStyleViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    var selectedRow = Int(Settings.interfaceStyle.rawValue - 1)
    if selectedRow < 0 || selectedRow >= tableView.numberOfRows(inSection: 0) {
      selectedRow = 0
    }

    let selectedIndex = IndexPath(row: selectedRow, section: 0)
    let selectedCell = tableView.cellForRow(at: selectedIndex)
    selectedCell?.accessoryType = .checkmark
  }

  override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    Settings.interfaceStyle = InterfaceStyle(rawValue: UInt(indexPath.row + 1))!
    view.window!.setInterfaceStyle(Settings.interfaceStyle)
    navigationController?.popViewController(animated: true)
  }
}
