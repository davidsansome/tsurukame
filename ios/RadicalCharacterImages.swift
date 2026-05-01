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

  static func pathForSubjectId(_ subjectId: Int64) -> String {
    "\(RadicalCharacterImages.cacheDirectoryPath)/radical-\(subjectId).png"
  }

  static func hasCachedImageForSubjectId(_ subjectId: Int64) -> Bool {
    FileManager.default.fileExists(atPath: pathForSubjectId(subjectId))
  }

  private let services: TKMServices

  init(services: TKMServices) {
    self.services = services

    do {
      try FileManager.default
        .createDirectory(at: URL(fileURLWithPath: RadicalCharacterImages.cacheDirectoryPath,
                                 isDirectory: true),
                         withIntermediateDirectories: true)
    } catch {
      NSLog("Failed to create cache directory: \(error)")
    }
  }

  func downloadAll() {
    Task.detached(priority: .background) { [unowned self] in
      self.services.localCachingClient.getAllSubjects().filter { subject in
        subject.hasRadical && subject.radical.hasCharacterImageFile_p
      }.forEach { subject in
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
            svgImage.size = CGSize(width: 180, height: 180)

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
