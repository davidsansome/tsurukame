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

import UIKit

class ViewController: UIViewController, DownloadModelDelegate {
  var tableModel: MutableTableModel?
  var tableView: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.white

    tableView = UITableView()
    view.addSubview(tableView!)

    tableModel = MutableTableModel(tableView: tableView)

    let fontLoader = FontLoader()
    for font in fontLoader.allFonts {
      assert(font.available)

      let item = DownloadModelItem(filename: "", title: font.displayName,
                                   totalSizeBytes: font.sizeBytes, delegate: self)
      item.transparentBackground = true
      item.previewFontName = font.fontName
      item.previewAccessibilityLabel = font.fontName
      item.previewText = Font.fontPreviewText
      tableModel!.add(item)
    }
  }

  override func viewWillLayoutSubviews() {
    tableView!.frame = CGRect(x: view.frame.minX, y: view.frame.minY,
                              width: 360, height: view.frame.height)
  }

  // MARK: - DownloadModelDelegate

  func didTap(downloadItem _: DownloadModelItem) {}
}
