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

import Compression
import Light_Untar
typealias TarProgressBlock = (Float) -> Void

extension FileManager {
  func untar(at path: String, tarData: Data, progressBlock: @escaping TarProgressBlock) throws {
    try createFilesAndDirectories(atPath: path, withTarData: tarData, progress: progressBlock)
  }
}

struct AudioPackage {
  var filename: String
  var title: String
  var sizeBytes: Int64
  init(_ filename: String, _ title: String, _ sizeBytes: Int64) {
    self.filename = filename
    self.title = title
    self.sizeBytes = sizeBytes
  }
}

@objcMembers class OfflineAudioViewController: TKMDownloadViewController {
  static let availablePackages: [AudioPackage] = [
    AudioPackage("a-levels-1-10.tar.lzfse", "Levels 1-10", 20_929_198),
    AudioPackage("a-levels-11-20.tar.lzfse", "Levels 11-20", 26_205_096),
    AudioPackage("a-levels-21-30.tar.lzfse", "Levels 21-30", 25_755_242),
    AudioPackage("a-levels-31-40.tar.lzfse", "Levels 31-40", 23_207_068),
    AudioPackage("a-levels-41-50.tar.lzfse", "Levels 41-50", 20_776_153),
    AudioPackage("a-levels-51-60.tar.lzfse", "Levels 51-60", 18_827_575),
  ]

  static func decompressLZFSE(compressedData: Data) -> Data? {
    if compressedData.count == 0 { return nil }

    // Assume a compression ratio of 1.25.
    var bufferSize = Int(Double(compressedData.count) * 1.25)

    func decompress(size bufferSize: inout Int, compressedData: Data) -> Data {
      NSLog("Decompressing data of size \(compressedData.count) into buffer of size \(bufferSize)")

      let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

      let decodedData = compressedData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data in
        let unsafePointer = buffer.bindMemory(to: UInt8.self).baseAddress!
        let decodedSize = compression_decode_buffer(destinationBuffer, bufferSize, unsafePointer,
                                                    compressedData.count, nil, COMPRESSION_LZFSE)

        if decodedSize == 0 {
          fatalError("Decoding failed")
        }
        if decodedSize == bufferSize {
          NSLog("Buffer wasn't big enough - trying again")
          bufferSize = Int(Double(bufferSize) * 1.25)
          return decompress(size: &bufferSize, compressedData: compressedData)
        }

        NSLog("Decompressed %lu bytes", decodedSize)
        return Data(bytes: destinationBuffer, count: decodedSize)
      }
      return decodedData
    }
    return decompress(size: &bufferSize, compressedData: compressedData)
  }

  let fileManager: FileManager

  required init?(coder: NSCoder) {
    fileManager = FileManager()
    super.init(coder: coder)
  }

  override func populateModel(_ model: TKMMutableTableModel) {
    model.addSection("", footer: """
    Download audio to your \(UIDevice.current.model) so it plays without \
    delay online and it's available when you're not connected to the Internet.
    """)

    for package in OfflineAudioViewController.availablePackages {
      let item = TKMDownloadModelItem(filename: package.filename, title: package.title,
                                      delegate: self)
      item.totalSizeBytes = package.sizeBytes

      if let download = activeDownload(for: package.filename) {
        item.downloadingProgressBytes = download.countOfBytesReceived
        item.state = TKMDownloadModelItemDownloading
      } else if Settings.installedAudioPackages.contains(package.filename) {
        item.state = TKMDownloadModelItemInstalledSelected
      } else {
        item.state = TKMDownloadModelItemNotInstalled
      }
      model.add(item)
    }

    if fileManager.fileExists(atPath: Audio.cacheDirectoryPath) {
      model.addSection()
      let deleteItem = TKMBasicModelItem(style: .default,
                                         title: "Delete all offline audio", subtitle: nil,
                                         accessoryType: UITableViewCell.AccessoryType.none,
                                         target: self,
                                         action: #selector(didTapDeleteAllAudio(sender:)))
      deleteItem.textColor = UIColor.systemRed
      model.add(deleteItem)
    }
  }

  override func url(forFilename filename: String) -> URL {
    URL(string: "https://tsurukame.app/audio/\(filename)")!
  }

  override func didFinishDownload(for filename: String, at location: URL) {
    guard let data = try? Data(contentsOf: location) else {
      fatalError("Error reading data: \(url(forFilename: filename).absoluteString)")
    }
    guard let tarData = OfflineAudioViewController.decompressLZFSE(compressedData: data) else {
      fatalError("Error decompressing data: \(url(forFilename: filename).absoluteString)")
    }
    do {
      try fileManager.untar(at: Audio.cacheDirectoryPath, tarData: tarData,
                            progressBlock: { (progress: Float) in
                              self.updateProgress(onMainThread: filename) {
                                $0.state = TKMDownloadModelItemInstalling
                                $0.installingProgress = progress
                              }
                            })
    } catch {
      fatalError("Error extracting data: \(url(forFilename: filename).absoluteString)")
    }

    DispatchQueue.main.async {
      Settings.installedAudioPackages.insert(filename)
      self.markDownloadComplete(filename)
    }
  }

  override func toggleItem(_: String, selected _: Bool) {}

  func deleteAllAudio() {
    do {
      try fileManager.removeItem(atPath: Audio.cacheDirectoryPath)
      Settings.installedAudioPackages = Set()
      rerender()
    } catch {
      fatalError("Error deleting files: " + error.localizedDescription)
    }
  }

  func didTapDeleteAllAudio(sender _: Any) {
    let c = UIAlertController(title: "Delete all offline audio", message: "Are you sure?",
                              preferredStyle: UIAlertController.Style.alert)
    c.addAction(UIAlertAction(title: "Delete", style: UIAlertAction.Style.destructive) { _ in
      self.deleteAllAudio()
    })
    c.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
    present(c, animated: true, completion: nil)
  }
}
