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
import PromiseKit

class OfflineAudio {
  private static let kFilePattern = "%@/a%d-%d.mp3"

  // Returns the local directory that contains cached audio files.
  private var cacheDirectoryPath: String {
    "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/audio"
  }

  // Returns the filename of an individual cached audio file.
  private func cacheFilename(subjectId: Int64, voiceActorId: Int64) -> String {
    String(format: OfflineAudio.kFilePattern, cacheDirectoryPath, subjectId,
           voiceActorId)
  }

  private let services: TKMServices

  // Serial queue that has one job - finding out what audio files need to be downloaded and adding
  // them to the downloadQueue.
  private let updateQueue: DispatchQueue

  // Serial queue that has one task for each audio file that needs to be downloaded.
  private let downloadQueue: DispatchQueue

  // List of work items that were added to downloadQueue last time. These will be cancelled on the
  // next call to queueDownloads. Only updateQueue is allowed to touch this list.
  private var downloadWorkItems = [DispatchWorkItem]()

  // Overall download progress. This Progress object is replaced on each call to queueDownloads.
  private(set) var lastProgress: Progress?

  private let nd = NotificationDispatcher()

  init(services: TKMServices) {
    self.services = services
    updateQueue = DispatchQueue(label: "offlineaudio.update", qos: .utility)
    downloadQueue = DispatchQueue(label: "offlineaudio.download", qos: .background)

    // Create the cache directory.
    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: cacheDirectoryPath),
                                             withIntermediateDirectories: true)

    nd.add(name: .lccUserInfoChanged) { [weak self] _ in self?.userInfoChanged() }
  }

  // MARK: - URLs and filesystem access

  // Returns the local file URL to an individual cached audio file. The file might not exist.
  func cacheUrl(subjectId: Int64, voiceActorId: Int64) -> URL {
    let filename = cacheFilename(subjectId: subjectId, voiceActorId: voiceActorId)
    return URL(fileURLWithPath: filename)
  }

  // Returns true if the given cached audio file is cached locally.
  func isCached(subjectId: Int64, voiceActorId: Int64) -> Bool {
    let filename = cacheFilename(subjectId: subjectId, voiceActorId: voiceActorId)
    return FileManager.default.fileExists(atPath: filename)
  }

  private func cacheUrl(item: LocalCachingClient.AudioUrl) -> URL {
    cacheUrl(subjectId: item.subjectId, voiceActorId: item.voiceActorId)
  }

  private func isCached(item: LocalCachingClient.AudioUrl) -> Bool {
    isCached(subjectId: item.subjectId, voiceActorId: item.voiceActorId)
  }

  // Calculates the total size in bytes of the audio cache.
  func cacheDirectorySize() -> Promise<Int64> {
    DispatchQueue.global(qos: .userInitiated).async(.promise) {
      var ret: Int64 = 0
      let it = FileManager.default.enumerator(at: URL(fileURLWithPath: self.cacheDirectoryPath),
                                              includingPropertiesForKeys: [.fileAllocatedSizeKey])!
      for url in it {
        if let url = url as? URL,
           let values = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey]),
           let size = values.fileAllocatedSize {
          ret += Int64(size)
        }
      }
      return ret
    }
  }

  // Deletes all files in the offline audio directory.
  func deleteAll() -> Promise<Void> {
    DispatchQueue.global(qos: .userInitiated).async(.promise) {
      let fm = FileManager.default
      let it = fm.enumerator(at: URL(fileURLWithPath: self.cacheDirectoryPath),
                             includingPropertiesForKeys: nil)!
      for url in it {
        if let url = url as? URL {
          try? fm.removeItem(at: url)
        }
      }
    }
  }

  // MARK: - Downloading audio

  // Starts downloading any audio files that do not already exist in the cache. Returns a new
  // Progress that can be used to track the progress of the downloads.
  // Calling this a second time will cancel and re-queue all pending downloads.
  func queueDownloads() -> Progress {
    // Handle upgrades from 1.22. Delete after 1.24.
    // If the user had any audio packages installed before, opt them in to offline audio now and
    // enable all the voice actors.
    if !Settings.installedAudioPackages.isEmpty {
      Settings.installedAudioPackages = []
      Settings.offlineAudio = true
      for voiceActor in services.localCachingClient.getVoiceActors() {
        Settings.offlineAudioVoiceActors.insert(voiceActor.id)
      }
    }

    let voiceActorIds = Array(Settings.offlineAudioVoiceActors)

    // Download levels in priority order, starting at the current level, then all previous levels,
    // then finally the next level.
    let currentLevel = Int(services.localCachingClient.getUserInfo()?.currentLevel ?? 1)
    let levels = [currentLevel] + (1 ..< currentLevel).reversed() + [currentLevel + 1]

    let progress = Progress(totalUnitCount: -1)
    lastProgress = progress

    updateQueue.async { [unowned self] in
      // Cancel all the work items that we started last time.
      self.downloadWorkItems.forEach { item in item.cancel() }
      self.downloadWorkItems.removeAll()

      // Don't do anything if offline audio is disabled.
      if !Settings.offlineAudio {
        progress.totalUnitCount = 0
        return
      }

      // Create a URL session.
      let config = URLSessionConfiguration.default
      config.allowsCellularAccess = Settings.offlineAudioCellular
      config.httpCookieStorage = nil
      if #available(iOS 11.0, *) {
        config.waitsForConnectivity = true
      }
      let session = URLSession(configuration: config)

      // Create a work item for each audio file.
      var workItems = [DispatchWorkItem]()
      let urls = self.services.localCachingClient.getAudioUrls(levels: levels,
                                                               voiceActorIds: voiceActorIds)

      // Sort by level, in the order of the levels list.
      let sortedUrls = urls.map { ($0, levels.firstIndex(of: $0.level) ?? 0) }
        .sorted(by: { $0.1 < $1.1 })
        .map { $0.0 }

      // Get all the subjects in all the selected levels.
      for item in sortedUrls {
        // Don't download the audio if it's locally cached already.
        if !self.isCached(item: item) {
          workItems.append(DispatchWorkItem { [unowned self] in
            self.downloadAudio(item, session: session, progress: progress)
          })
        }
      }

      // Start each item.
      progress.totalUnitCount = Int64(workItems.count)
      workItems.forEach { item in self.downloadQueue.async(execute: item) }
      self.downloadWorkItems = workItems
    }

    return progress
  }

  private func downloadAudio(_ item: LocalCachingClient.AudioUrl, session: URLSession,
                             progress: Progress) {
    // Check again if the file has been downloaded already.
    if isCached(item: item) {
      progress.completedUnitCount += 1
      return
    }
    let destination = cacheUrl(item: item)

    let task = session.downloadTask(with: URL(string: item.url)!) { tempUrl, _, err in
      progress.completedUnitCount += 1

      if let err = err {
        NSLog("Failed to download audio from %@: %@", item.url, String(describing: err))
        return
      }
      guard let tempUrl = tempUrl else { return }
      do {
        try FileManager.default.moveItem(at: tempUrl, to: destination)
      } catch {
        NSLog("Failed to move downloaded audio from %@ to %@: %@",
              tempUrl.absoluteString, destination.absoluteString, String(describing: error))
        return
      }
    }

    task.resume()
  }

  // MARK: - Notification handlers

  private var lastLevel: Int32 = 0
  private func userInfoChanged() {
    // Queue any audio downloads when the user's level changes.
    if let level = services.localCachingClient.getUserInfo()?.level, level != lastLevel {
      lastLevel = level
      _ = queueDownloads()
    }
  }
}
