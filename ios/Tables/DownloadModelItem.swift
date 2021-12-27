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
import UIKit

protocol DownloadModelDelegate: AnyObject {
  func didTap(downloadItem: DownloadModelItem)
}

class DownloadModelItem: NSObject, TKMModelItem {
  enum State {
    case notInstalled
    case downloading
    case installing
    case installedNotSelected
    case installedSelected
  }

  let filename: String
  let title: String
  let totalSizeBytes: Int64
  weak var delegate: DownloadModelDelegate?

  var transparentBackground = false
  var previewText: String?
  var previewFontName: String?
  var previewAccessibilityLabel: String?
  var previewImage: UIImage?

  var state: State = .notInstalled
  var downloadingProgressBytes: Int64 = 0
  var installingProgress: Float = 0.0

  init(filename: String, title: String, totalSizeBytes: Int64, delegate: DownloadModelDelegate?) {
    self.filename = filename
    self.title = title
    self.totalSizeBytes = totalSizeBytes
    self.delegate = delegate
  }

  func cellNibName() -> String! {
    "DownloadModelItem"
  }
}

class DownloadModelView: TKMModelCell {
  @IBOutlet var previewContainer: UIView!
  @IBOutlet var preview: UILabel!
  @IBOutlet var previewImageView: UIImageView!
  @IBOutlet var subtitle: UILabel!
  @IBOutlet var title: UILabel!
  @IBOutlet var icon: UIImageView!

  override func update(with item: TKMModelItem!) {
    super.update(with: item)
    let item = item as! DownloadModelItem

    if item.transparentBackground {
      backgroundColor = .clear
    } else {
      backgroundColor = TKMStyle.Color.cellBackground
    }

    title.text = item.title

    switch item.state {
    case .notInstalled:
      subtitle.text = "not installed - \(friendlySize(bytes: item.totalSizeBytes))"
      icon.image = UIImage(named: "baseline_cloud_download_black_24pt")
      icon.tintColor = TKMStyle.defaultTintColor
    case .downloading, .installing:
      updateProgress()
      icon.image = UIImage(named: "baseline_cancel_black_24pt")
      icon.tintColor = TKMStyle.Color.grey66
    case .installedSelected:
      subtitle.text = nil
      icon.image = UIImage(named: "tick")
      icon.tintColor = TKMStyle.defaultTintColor
    case .installedNotSelected:
      subtitle.text = nil
      icon.image = UIImage(named: "tick")
      icon.tintColor = TKMStyle.Color.grey66
    }

    preview.isHidden = true
    previewImageView.isHidden = true
    if let previewText = item.previewText {
      preview.isHidden = false
      preview.text = previewText
      if let previewFontName = item.previewFontName {
        preview.font = UIFont(name: previewFontName, size: 24.0)
      } else {
        preview.font = nil
      }
      preview.accessibilityLabel = item.previewAccessibilityLabel
    } else if let previewImage = item.previewImage {
      previewImageView.isHidden = false
      previewImageView.image = previewImage
      previewImageView.contentMode = .scaleAspectFit
    }
    previewContainer.isHidden = preview.isHidden && previewImageView.isHidden
  }

  private func friendlySize(bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }

  func updateProgress() {
    let item = self.item as! DownloadModelItem

    switch item.state {
    case .downloading:
      let percent = item.downloadingProgressBytes * 100 / item.totalSizeBytes
      subtitle.text = "downloading \(percent)%"
    case .installing:
      let percent = Int(item.installingProgress * 100)
      subtitle.text = "installing \(percent)%"

    default:
      break
    }
  }

  override func didSelect() {
    let item = self.item as! DownloadModelItem
    if let delegate = item.delegate {
      delegate.didTap(downloadItem: item)
    }
  }
}
