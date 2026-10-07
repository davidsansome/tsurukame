// Copyright 2026 David Sansome
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

import SVGKit
import WaniKaniAPI

class RadicalCharacterImages {
  private static var cacheDirectoryPath: String {
    "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/radical-images"
  }

  // Size before pixel scaling.
  private static let imageSizePx = 60

  static func pathForSubjectId(_ subjectId: Int64) -> String {
    let path = RadicalCharacterImages.cacheDirectoryPath
    let scale = Int(UIScreen.main.scale)
    return "\(path)/radical-\(subjectId)-\(imageSizePx)px@\(scale)x.png"
  }

  static func hasCachedImageForSubjectId(_ subjectId: Int64) -> Bool {
    FileManager.default.fileExists(atPath: pathForSubjectId(subjectId))
  }

  private let services: TKMServices

  // Whether downloadAll() has anything new to look at: true at launch and after a sync brings in
  // new or changed subjects. Checking every radical on every sync held the database long enough
  // to freeze the home screen.
  private let lock = NSLock()
  private var needsDownload = true

  init(services: TKMServices) {
    self.services = services
    NotificationCenter.default.addObserver(forName: .lccSubjectsChanged, object: nil,
                                           queue: nil) { [weak self] _ in
      self?.setNeedsDownload(true)
    }

    do {
      try FileManager.default
        .createDirectory(at: URL(fileURLWithPath: RadicalCharacterImages.cacheDirectoryPath,
                                 isDirectory: true),
                         withIntermediateDirectories: true)
    } catch {
      NSLog("Failed to create cache directory: \(error)")
    }
  }

  private func setNeedsDownload(_ value: Bool) {
    lock.lock()
    needsDownload = value
    lock.unlock()
  }

  // Downloads any radical images that aren't cached yet. Does nothing unless subjects have changed
  // since the last time.
  func downloadAll() {
    lock.lock()
    let shouldDownload = needsDownload
    needsDownload = false
    lock.unlock()
    if !shouldDownload {
      return
    }

    Task.detached(priority: .background) { [unowned self] in
      self.services.localCachingClient.getRadicalsWithCharacterImages().forEach { subject in
        let id = subject.id

        // Don't do anything if we've got this image already.
        if RadicalCharacterImages.hasCachedImageForSubjectId(id) {
          return
        }

        let url = URL(string: subject.radical.characterImage)!
        let destinationPath = RadicalCharacterImages.pathForSubjectId(id)

        // Fetch the image.
        do {
          NSLog("Fetching \(url)")
          URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let svgImage = SVGKImage(data: data) else {
              NSLog("Failed to load SVG from \(url)")
              return
            }

            // Scale down the image before rasterising it.
            svgImage.size = CGSize(width: RadicalCharacterImages.imageSizePx,
                                   height: RadicalCharacterImages.imageSizePx)

            guard let image = svgImage.uiImage, let pngData = image.pngData() else {
              NSLog("Failed to convert SVG to PNG \(url)")
              return
            }

            // Write it to the destination.
            do {
              try pngData.write(to: URL(fileURLWithPath: destinationPath))
              NSLog("Wrote image to \(destinationPath)")
            } catch {}
          }.resume()
        }
      }
    }
  }
}

func japaneseText(_ subject: TKMSubject, imageSize: CGFloat = 0.0) -> NSAttributedString {
  if !subject.hasRadical || !subject.radical.hasCharacterImageFile_p ||
    !RadicalCharacterImages.hasCachedImageForSubjectId(subject.id) {
    return NSAttributedString(string: subject.japanese)
  }

  let image = UIImage(contentsOfFile: RadicalCharacterImages.pathForSubjectId(subject.id))
  let templateImage = image?.withRenderingMode(.alwaysTemplate)

  let imageAttachment = NSTextAttachment()
  imageAttachment.image = templateImage

  var size = imageSize
  if size == 0 {
    size = imageAttachment.image?.size.width ?? 0
  }
  imageAttachment.bounds = CGRect(x: 0, y: 0, width: size, height: size)
  return NSAttributedString(attachment: imageAttachment)
}
