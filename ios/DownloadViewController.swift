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

protocol DownloadViewControllerProtocol: DownloadViewControllerClass {
  func populateModel(_: MutableTableModel)
  func urlForFilename(_: String) -> URL
  func didFinishDownload(filename: String, url: URL)
  func toggleItem(filename: String, selected: Bool)
}

typealias DownloadViewController = DownloadViewControllerClass & DownloadViewControllerProtocol

class DownloadViewControllerClass: UITableViewController,
  URLSessionDownloadDelegate,
  DownloadModelDelegate {
  private var urlSession: URLSession!
  private var model: TableModel!

  private var downloads = [String: URLSessionDownloadTask]()
  private var indexPaths = [String: IndexPath]()

  required init?(coder: NSCoder) {
    super.init(coder: coder)

    let config = URLSessionConfiguration.default
    urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }

  func activeDownload(filename: String) -> URLSessionDownloadTask? {
    downloads[filename]
  }

  func rerender() {
    let controller = self as! DownloadViewController
    let model = MutableTableModel(tableView: tableView)
    controller.populateModel(model)

    // Index the items.
    indexPaths.removeAll()
    for section in 0 ..< model.sectionCount {
      let items = model.items(inSection: section)
      for i in 0 ..< items.count {
        if let downloadItem = items[i] as? DownloadModelItem {
          indexPaths[downloadItem.filename] = IndexPath(item: i, section: section)
        }
      }
    }

    self.model = model
    model.reloadTable()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.navigationBar.isHidden = false
    rerender()
  }

  func didTap(downloadItem: DownloadModelItem) {
    let controller = self as! DownloadViewController

    switch downloadItem.state {
    case .notInstalled:
      startDownload(downloadItem)
    case .downloading:
      cancelDownload(downloadItem)
    case .installedNotSelected:
      controller.toggleItem(filename: downloadItem.filename, selected: true)
      rerender()
    case .installedSelected:
      controller.toggleItem(filename: downloadItem.filename, selected: false)
      rerender()
    case .installing:
      break
    }
  }

  private func startDownload(_ downloadItem: DownloadModelItem) {
    let controller = self as! DownloadViewController
    let url = controller.urlForFilename(downloadItem.filename)
    let task = urlSession.downloadTask(with: url)

    downloads[downloadItem.filename] = task
    task.resume()
    rerender()
  }

  private func cancelDownload(_ downloadItem: DownloadModelItem) {
    guard let task = downloads[downloadItem.filename] else {
      return
    }
    task.cancel()
    downloads.removeValue(forKey: downloadItem.filename)
    rerender()
  }

  func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    guard let controller = self as? DownloadViewController,
          let url = downloadTask.originalRequest?.url,
          let httpResponse = downloadTask.response as? HTTPURLResponse else {
      return
    }
    let filename = url.lastPathComponent

    if httpResponse.statusCode != 200 {
      reportErrorOnMainThread(filename: filename, title: "HTTP error \(httpResponse.statusCode)",
                              message: url.absoluteString)
      return
    }

    controller.didFinishDownload(filename: filename, url: location)
  }

  private func updateProgressOnMainThread(filename: String,
                                          fn: @escaping (_: DownloadModelItem) -> Void) {
    DispatchQueue.main.async {
      // Try to update the visible cell without reloading the whole table.  This is a bit of a hack.
      if let indexPath = self.indexPaths[filename],
         let cell = self.tableView.cellForRow(at: indexPath),
         let view = cell as? DownloadModelView,
         let item = view.item as? DownloadModelItem {
        fn(item)
        view.updateProgress()
      }
    }
  }

  func reportErrorOnMainThread(filename: String?, title: String, message: String) {
    DispatchQueue.main.async {
      if let filename = filename {
        self.downloads.removeValue(forKey: filename)
      }

      let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
      ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      self.present(ac, animated: true, completion: nil)
      self.rerender()
    }
  }

  func markDownloadComplete(filename: String) {
    downloads.removeValue(forKey: filename)
    rerender()
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error = error as? URLError,
          let url = task.originalRequest?.url else {
      return
    }
    if error.code == .cancelled {
      return
    }

    let filename = url.lastPathComponent
    reportErrorOnMainThread(filename: filename, title: error.localizedDescription,
                            message: url.absoluteString)
  }

  func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                  totalBytesWritten: Int64, totalBytesExpectedToWrite _: Int64) {
    guard let filename = downloadTask.originalRequest?.url?.lastPathComponent else {
      return
    }

    updateProgressOnMainThread(filename: filename) { item in
      item.state = .downloading
      item.downloadingProgressBytes = totalBytesWritten
    }
  }
}
