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

@objc(TKMFontSizeViewController)
class FontSizeViewController: UITableViewController {
  let fontSizeByRow: [Float] = [
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.25,
    2.5,
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    assert(fontSizeByRow.count == tableView.numberOfRows(inSection: 0))

    let row = fontSizeByRow.firstIndex(of: Settings.fontSize) ?? 0
    tableView.cellForRow(at: IndexPath(row: row, section: 0))?.accessoryType = .checkmark
  }

  override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    Settings.fontSize = fontSizeByRow[indexPath.row]
    navigationController?.popViewController(animated: true)
  }
}
