// Copyright David Sansome
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
import SVGKit

class RadicalMnemonicImages {
  static let rasterSize = CGSize(width: 512, height: 512)

  static func pathForSubjectId(_ subjectId: Int64) -> String {
    let path = cacheDirectoryPath
    let scale = Int(UIScreen.main.scale)
    let imageSizePx = Int(rasterSize.width)
    return "\(path)/radical-\(subjectId)-\(imageSizePx)px@\(scale)x.png"
  }

  private let services: TKMServices
  private let lock = NSLock()
  private var needsDownload = true
  private let nd = NotificationDispatcher()

  init(services: TKMServices) {
    self.services = services
    NotificationCenter.default.addObserver(forName: .lccSubjectsChanged, object: nil,
                                           queue: nil) { [weak self] _ in
      self?.setNeedsDownload(true)
    }

    do {
      try FileManager.default
        .createDirectory(at: URL(fileURLWithPath: Self.cacheDirectoryPath,
                                 isDirectory: true),
                         withIntermediateDirectories: true)
    } catch {
      NSLog("[RadicalMnemonic] Failed to create cache directory: \(error)")
    }
    nd.add(name: .lccUserInfoChanged) { [weak self] _ in self?.userInfoChanged() }
  }

  private static var cacheDirectoryPath: String {
    "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])/radical-mnemonics"
  }

  private func setNeedsDownload(_ value: Bool) {
    lock.lock()
    needsDownload = value
    lock.unlock()
  }

  func downloadByLevel(byLevel level: Int) {
    // Don't do anything if showRadicalMnemonic is disabled. The pending flag is kept, so the
    // download still happens once the setting is enabled.
    guard Settings.showRadicalMnemonic else {
      return
    }

    lock.lock()
    let shouldDownload = needsDownload
    needsDownload = false
    lock.unlock()
    if !shouldDownload {
      return
    }

    Task.detached(priority: .background) { [weak self] in
      guard let self else { return }
      for subject in self.services.localCachingClient.getRadicals(byLevel: level) {
        await self.downloadRadical(subject.id)
      }
    }
  }

  private func downloadRadical(_ id: Int64) async {
    // Don't do anything if we've got this image already.
    if SVGImageCache.hasCachedImageForSubjectId(id) {
      return
    }
    if let radicalURLString = ArtworkManager.radicalFullURL(subjectId: id),
       let url = URL(string: radicalURLString) {
      do {
        _ = try await SVGImageLoader.shared.image(from: url, subjectId: id)
      } catch {
        NSLog("[RadicalMnemonic] downloadRadical error: \(error)")
      }
    }
  }

  // MARK: - Notification handlers

  private var lastLevel: Int32 = 0
  private func userInfoChanged() {
    if let level = services.localCachingClient.getUserInfo()?.level, level != lastLevel {
      lastLevel = level
      setNeedsDownload(true)
    }
  }
}

// MARK: - Cache

final class SVGImageCache: @unchecked Sendable {
  static func key(subjectId: Int64) -> String {
    RadicalMnemonicImages.pathForSubjectId(subjectId)
  }

  static func hasCachedImageForSubjectId(_ subjectId: Int64) -> Bool {
    FileManager.default.fileExists(atPath: key(subjectId: subjectId))
  }

  static func image(subjectId: Int64) -> UIImage? {
    let destinationPath = Self.key(subjectId: subjectId)
    if FileManager.default.fileExists(atPath: destinationPath) {
      if let image = UIImage(contentsOfFile: destinationPath) {
        return image
      }
    }
    return nil
  }

  static func insert(_ image: UIImage, subjectId: Int64) {
    let destinationPath = Self.key(subjectId: subjectId)
    guard let pngData = image.pngData() else {
      NSLog("[RadicalMnemonic] Cache Failed to convert SVG to PNG \(destinationPath)")
      return
    }
    let directoryURL = URL(fileURLWithPath: destinationPath).deletingLastPathComponent()
    do {
      // The system may purge the caches directory, so make sure it exists before writing.
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      // Atomic write: an interrupted save never leaves a truncated PNG behind.
      try pngData.write(to: URL(fileURLWithPath: destinationPath), options: .atomic)
    } catch {
      // Failing to save is not critical: the image is rendered and saved again on a later load.
    }
  }
}

// MARK: - Loader

/// Loads images through the cache and shares in-flight requests: concurrent callers asking for
/// the same subject wait for a single download/transform/render.
actor SVGImageLoader {
  static let shared = SVGImageLoader()

  private var inFlight: [String: Task<UIImage, Error>] = [:]

  /// `nonisolated`: the cache lookup (disk read + PNG decode) runs outside the actor, so it does
  /// not block other callers while it works.
  nonisolated func image(from url: URL, subjectId: Int64) async throws -> UIImage {
    let key = SVGImageCache.key(subjectId: subjectId)
    if let cached = SVGImageCache.image(subjectId: subjectId) {
      return cached
    }

    return try await loadShared(from: url, subjectId: subjectId, key: key)
  }

  /// Actor-isolated: only keeps the in-flight bookkeeping, the heavy work runs in a detached task.
  private func loadShared(from url: URL, subjectId: Int64, key: String) async throws -> UIImage {
    if let existing = inFlight[key] {
      return try await existing.value
    }

    // Detached so that rendering and the PNG write do not run on the actor. It keeps the caller's
    // priority (e.g. `.background` for the prefetch).
    let task = Task.detached(priority: Task.currentPriority) { () throws -> UIImage in
      // A load that finished after the caller's cache miss may have saved the image already.
      if let cached = SVGImageCache.image(subjectId: subjectId) {
        return cached
      }
      let image = try await SVGMnemonicRenderer.renderImage(from: url)
      SVGImageCache.insert(image, subjectId: subjectId)
      return image
    }
    inFlight[key] = task
    defer { inFlight[key] = nil }

    return try await task.value
  }
}

// MARK: - Download, transform and render

enum SVGMnemonicError: Error {
  case invalidResponse(statusCode: Int?)
  case parseFailed
  case encodingFailed
  case renderFailed
}

enum XMLExtractionError: Error {
  case clipPathNotFound
  case clipPathClosingTagNotFound
  case defsClosingTagNotFound
}

enum SVGMnemonicRenderer {
  private static let canvasSize = 1420.0

  private static let baseDefs: String = """
  <defs>
      <style>
          .highlight { fill: #00aaff }
          .opacity-25 { opacity: 0.25 }
          .opacity-50 { opacity: 0.5 }
          .opacity-75 { opacity: 0.75 }
      </style>
  </defs>
  """

  // Regular expressions are compiled once and reused across renders.
  private static let defsBlockRegex =
    try? NSRegularExpression(pattern: #"<defs\b[^>]*>[\s\S]*?</defs>"#,
                             options: [])
  private static let classAttributeRegex =
    try? NSRegularExpression(pattern: #"\s*\bclass\s*=\s*(["'])[\s\S]*?\1"#,
                             options: [.caseInsensitive])
  private static let halftoneGroupRegex =
    try? NSRegularExpression(pattern: #"<g\b[^>]*\bid=["']halftone["'][^>]*>([\s\S]*?)</g>"#,
                             options: [.caseInsensitive])
  private static let groupTagRegex = try? NSRegularExpression(pattern: #"<g\b([^>]*)>"#,
                                                              options: [])
  private static let groupClassAttributeRegex =
    try? NSRegularExpression(pattern: #"\s+class\s*=\s*(?:"[^"]*"|'[^']*')"#,
                             options: [])
  private static let groupIdAttributeRegex =
    try? NSRegularExpression(pattern: #"\bid\s*=\s*("[^"]*"|'[^']*')"#,
                             options: [])
  private static let clipPathOpenTagRegex =
    try? NSRegularExpression(pattern: #"<clipPath\s+id="clip-path-0"[^>]*>"#,
                             options: [])

  /// Emulates `<pattern>` (not supported by SVGKit). Generated only once.
  private static let halftoneDots: String = {
    let spacing = 16.0
    let radius = 3.0
    let diameter = radius * 2

    let rows = Int(canvasSize / (spacing / 2)) + 1
    let columns = Int(canvasSize / spacing) + 1

    var path = ""
    path.reserveCapacity(rows * columns * 64)

    for row in 0 ..< rows {
      let y = Double(row) * spacing / 2
      let offset = row.isMultiple(of: 2) ? 0.0 : spacing / 2

      for column in 0 ..< columns {
        let x = Double(column) * spacing + offset
        path += "M\(x - radius) \(y) a\(radius) \(radius) 0 1 0 \(diameter) 0 "
        path += "a\(radius) \(radius) 0 1 0 -\(diameter) 0 "
      }
    }

    return path
  }()

  static func renderImage(from url: URL) async throws -> UIImage {
    let rawData = try await downloadSVGData(from: url)
    let sourceData = await prepareSVGData(from: rawData)
    return try await rasterizeSVG(data: sourceData)
  }

  private static func downloadSVGData(from url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.setValue("image/svg+xml,image/wk-svg", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
      throw SVGMnemonicError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode)
    }
    return data
  }

  private static func prepareSVGData(from originalData: Data) async -> Data {
    var halftone = false

    if let rawSVG = String(data: originalData, encoding: .utf8) {
      if rawSVG.contains("halftone") {
        halftone = true
      }
    }

    guard halftone else {
      return originalData
    }

    do {
      let resultSVG = try transformXMLSimple(data: originalData)
      guard let encoded = resultSVG.data(using: .utf8) else {
        throw SVGMnemonicError.encodingFailed
      }

      return encoded
    } catch {
      NSLog("[RadicalMnemonic] Halftone transform failed (\(error)), falling back to original SVG.")
      return originalData
    }
  }

  private static func rasterizeSVG(data: Data) async throws -> UIImage {
    try await MainActor.run { () throws -> UIImage in
      guard let svgImage = SVGKImage(data: data) else {
        NSLog("[RadicalMnemonic] SVGKit was unable to create an SVGKImage")
        throw SVGMnemonicError.renderFailed
      }

      svgImage.size = RadicalMnemonicImages.rasterSize
      guard let image = svgImage.uiImage else {
        NSLog("[RadicalMnemonic] UIImage: nil")
        throw SVGMnemonicError.renderFailed
      }

      return image
    }
  }

  private static func transformXMLSimple(data: Data) throws -> String {
    guard var result = String(data: data, encoding: .utf8) else {
      throw SVGMnemonicError.parseFailed
    }

    let numPaths = result.components(separatedBy: "<path").count - 1
    NSLog("[RadicalMnemonic] SVG has \(numPaths) paths.")
    result = replaceDefsBlock(in: result)
    result = removeAttributeClass(in: result)
    result = convertHalftoneGroupToClipPath(in: result)
    result = try moveClipPathToEndOfDefs(in: result)
    result = replaceClassForId(in: result)

    // Validate the structure before inserting the halftone path. The dots are generated and always
    // valid, and the document is still small here, so this is cheap. If the regex transforms
    // produced invalid XML, the caller falls back to the original SVG.
    guard XMLParser(data: Data(result.utf8)).parse() else {
      throw SVGMnemonicError.parseFailed
    }

    result = result.replacingOccurrences(of: "{{ HALFTONE_DOTS }}", with: halftoneDots)
    return result
  }

  private static func replaceDefsBlock(in xml: String) -> String {
    var updatedXML = xml

    if let defsRegex = Self.defsBlockRegex {
      let fullNSRange = NSRange(updatedXML.startIndex ..< updatedXML.endIndex, in: updatedXML)
      updatedXML = defsRegex.stringByReplacingMatches(in: updatedXML,
                                                      options: [],
                                                      range: fullNSRange,
                                                      withTemplate: NSRegularExpression
                                                        .escapedTemplate(for: baseDefs))
    }

    return updatedXML
  }

  private static func removeAttributeClass(in html: String) -> String {
    guard let regex = classAttributeRegex else {
      return html
    }
    let rango = NSRange(html.startIndex ..< html.endIndex, in: html)
    return regex.stringByReplacingMatches(in: html, options: [], range: rango,
                                          withTemplate: "")
  }

  private static func convertHalftoneGroupToClipPath(in svgString: String) -> String {
    let replacement = #"<clipPath id="clip-path-0">$1</clipPath>"#

    guard let regex = Self.halftoneGroupRegex else {
      return svgString
    }

    let range = NSRange(svgString.startIndex ..< svgString.endIndex, in: svgString)
    return regex.stringByReplacingMatches(in: svgString, options: [], range: range,
                                          withTemplate: replacement)
  }

  private static func moveClipPathToEndOfDefs(in xml: String) throws -> String {
    let fullNSRange = NSRange(xml.startIndex ..< xml.endIndex, in: xml)
    guard let openTagRegex = Self.clipPathOpenTagRegex,
          let openMatch = openTagRegex.firstMatch(in: xml, options: [], range: fullNSRange),
          let openRange = Range(openMatch.range, in: xml) else {
      throw XMLExtractionError.clipPathNotFound
    }

    let closeClipPathTag = "</clipPath>"
    guard let closeClipPathRange = xml.range(of: closeClipPathTag,
                                             range: openRange.upperBound ..< xml.endIndex) else {
      throw XMLExtractionError.clipPathClosingTagNotFound
    }

    let fullClipPathRange = openRange.lowerBound ..< closeClipPathRange.upperBound
    let clipPathBlock = String(xml[fullClipPathRange])

    var updatedXML = xml
    updatedXML.replaceSubrange(fullClipPathRange, with: """
      <g clip-path="url(#clip-path-0)"><path d="{{ HALFTONE_DOTS }}"/></g>
    """)

    let defsCloseTag = "</defs>"
    guard let defsRange = updatedXML.range(of: defsCloseTag) else {
      throw XMLExtractionError.defsClosingTagNotFound
    }
    updatedXML.insert(contentsOf: clipPathBlock + "\n", at: defsRange.lowerBound)
    return updatedXML
  }

  private static func replaceClassForId(in xml: String) -> String {
    var updatedXML = xml
    if let gRegex = Self.groupTagRegex,
       let classAttrRegex = Self.groupClassAttributeRegex,
       let idAttrRegex = Self.groupIdAttributeRegex {
      let fullNSRange = NSRange(updatedXML.startIndex ..< updatedXML.endIndex, in: updatedXML)
      let matches = gRegex.matches(in: updatedXML, options: [], range: fullNSRange)

      for match in matches.reversed() {
        guard let tagRange = Range(match.range, in: updatedXML),
              let attrsRange = Range(match.range(at: 1), in: updatedXML) else {
          continue
        }

        var attrs = String(updatedXML[attrsRange])
        let attrsNSRange = NSRange(attrs.startIndex ..< attrs.endIndex, in: attrs)

        attrs = classAttrRegex.stringByReplacingMatches(in: attrs,
                                                        options: [],
                                                        range: attrsNSRange,
                                                        withTemplate: "")

        let updatedAttrsNSRange = NSRange(attrs.startIndex ..< attrs.endIndex, in: attrs)
        attrs = idAttrRegex.stringByReplacingMatches(in: attrs,
                                                     options: [],
                                                     range: updatedAttrsNSRange,
                                                     withTemplate: "class=$1")

        updatedXML.replaceSubrange(tagRange, with: "<g\(attrs)>")
      }
    }
    return updatedXML
  }
}
