// Copyright 2022 David Sansome
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

class FontsViewController: DownloadViewController {
  let fileManager = FileManager()
  var services: TKMServices!

  func setup(services: TKMServices) {
    self.services = services
  }

  func populateModel(_ model: MutableTableModel) {
    model.add(section: "",
              footer: "Choose the fonts you want to use while doing reviews. " +
                "Tsurukame will pick a random font from the ones you've selected for every new " +
                "word.")
    model.addSection()

    for font in services.fontLoader.allFonts {
      let item = DownloadModelItem(filename: font.fileName, title: font.displayName,
                                   totalSizeBytes: font.sizeBytes, delegate: self)

      if activeDownload(filename: font.fileName) != nil {
        item.previewImage = font.loadScreenshot()
        item.state = .downloading
      } else if font.available {
        item.previewText = Font.fontPreviewText
        item.previewFontName = font.fontName
        if Settings.selectedFonts.contains(font.fileName) {
          item.state = .installedSelected
        } else {
          item.state = .installedNotSelected
        }
      } else {
        item.previewImage = font.loadScreenshot()
        item.state = .notInstalled
      }
      model.add(item)
    }

    if fileManager.fileExists(atPath: FontLoader.cacheDirectoryPath) {
      model.addSection()
      let deleteItem = BasicModelItem(style: .default, title: "Delete all downloaded fonts",
                                      tapHandler: didTapDeleteAllFonts)
      deleteItem.textColor = .systemRed
      model.add(deleteItem)
    }
  }

  func urlForFilename(_ filename: String) -> URL {
    URL(string: "https://tsurukame.app/fonts/\(filename)")!
  }

  func didFinishDownload(filename: String, url: URL) {
    // Create the cache directory.
    do {
      try fileManager.createDirectory(atPath: FontLoader.cacheDirectoryPath,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
    } catch {
      reportErrorOnMainThread(filename: filename, title: "Error creating directory",
                              message: error.localizedDescription)
      return
    }

    // Move the downloaded file to the cache directory.
    let destination = URL(fileURLWithPath: "\(FontLoader.cacheDirectoryPath)/\(filename)")
    do {
      try fileManager.moveItem(at: url, to: destination)
    } catch {
      reportErrorOnMainThread(filename: filename, title: "Error moving downloaded file",
                              message: error.localizedDescription)
    }

    DispatchQueue.main.async {
      self.services.fontLoader.font(fileName: filename)?.reload()
      self.toggleItem(filename: filename, selected: true)
      self.markDownloadComplete(filename: filename)
    }
  }

  func toggleItem(filename: String, selected: Bool) {
    var selectedFonts = Settings.selectedFonts
    if selected {
      selectedFonts.insert(filename)
    } else {
      selectedFonts.remove(filename)
    }
    Settings.selectedFonts = selectedFonts
  }

  private func didTapDeleteAllFonts() {
    let ac = UIAlertController(title: "Delete all downloaded fonts", message: "Are you sure?",
                               preferredStyle: .alert)
    ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [unowned self] _ in
      self.deleteAllFonts()
    }))
    ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(ac, animated: true, completion: nil)
  }

  private func deleteAllFonts() {
    do {
      try fileManager.removeItem(atPath: FontLoader.cacheDirectoryPath)
    } catch {
      reportErrorOnMainThread(filename: nil, title: "Error deleting files",
                              message: error.localizedDescription)
      return
    }

    Settings.selectedFonts = Set<String>()
    for font in services.fontLoader.allFonts {
      font.didDelete()
    }
    rerender()
  }
}
