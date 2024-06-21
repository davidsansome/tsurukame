// Copyright 2024 David Sansome
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

import AVFoundation
import Foundation

protocol AudioDelegate: NSObject {
  func audioPlaybackStateChanged(state: Audio.PlaybackState)
}

class Audio: NSObject {
  enum PlaybackState {
    case loading
    case playing
    case finished
  }

  private let services: TKMServices
  private var player: AVPlayer?
  private var lastPlayedAudioIndex: Int = 0
  private var waitingToPlay = false
  private weak var delegate: AudioDelegate?

  private let nd = NotificationDispatcher()

  init(services: TKMServices) {
    self.services = services

    super.init()

    // Set the audio session category.
    let session = AVAudioSession.sharedInstance()
    try? session
      .setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])

    // Listen for when playback of any item finished.
    nd.add(name: .AVPlayerItemDidPlayToEndTime) { [weak self] _ in self?.itemFinishedPlaying() }
  }

  private(set) var currentState = PlaybackState.finished {
    didSet {
      if currentState != oldValue {
        delegate?.audioPlaybackStateChanged(state: currentState)
      }

      let session = AVAudioSession.sharedInstance()
      switch currentState {
      case .playing:
        try? session.setActive(true, options: [])
      case .finished:
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
      default:
        break
      }
    }
  }

  func play(subjectID: Int64, delegate: AudioDelegate?) {
    guard let subject = services.localCachingClient.getSubject(id: subjectID) else {
      return
    }
    if !subject.hasVocabulary || subject.vocabulary.audio.isEmpty {
      return
    }
    let offline = services.offlineAudio!

    lastPlayedAudioIndex += 1
    if lastPlayedAudioIndex >= subject.vocabulary.audio.count {
      lastPlayedAudioIndex = 0
    }
    let audio = subject.vocabulary.audio[lastPlayedAudioIndex]

    // Is the audio available offline?
    if offline.isCached(subjectId: subject.id, voiceActorId: audio.voiceActorID) {
      play(url: offline.cacheUrl(subjectId: subject.id, voiceActorId: audio.voiceActorID),
           delegate: delegate)
      return
    }

    // Maybe one of the other voice actors' audio is available offline.
    for (index, audio) in subject.vocabulary.audio.enumerated() {
      if offline.isCached(subjectId: subject.id, voiceActorId: audio.voiceActorID) {
        lastPlayedAudioIndex = index
        play(url: offline.cacheUrl(subjectId: subject.id, voiceActorId: audio.voiceActorID),
             delegate: delegate)
        return
      }
    }

    if !services.reachability.isReachable() {
      showOfflineDialog()
      return
    }

    play(url: URL(string: audio.url)!, delegate: delegate)
  }

  private func play(url: URL, delegate: AudioDelegate?) {
    currentState = .finished
    self.delegate = delegate

    if player == nil || player?.status == .failed {
      player = AVPlayer()
      player?.addObserver(self, forKeyPath: "currentItem.status", options: [], context: nil)
    }

    player?.replaceCurrentItem(with: AVPlayerItem(url: url))
    waitingToPlay = true
  }

  func stopPlayback() {
    player?.pause()
    currentState = .finished
  }

  override func observeValue(forKeyPath keyPath: String?,
                             of _: Any?,
                             change _: [NSKeyValueChangeKey: Any]?,
                             context _: UnsafeMutableRawPointer?) {
    if keyPath == "currentItem.status" {
      guard let player = player,
            let currentItem = player.currentItem else {
        return
      }

      switch currentItem.status {
      case .failed:
        showErrorDialog(currentItem.error!)
        currentState = .finished
      case .unknown:
        currentState = .loading
      case .readyToPlay:
        if waitingToPlay {
          waitingToPlay = false
          currentState = .playing
          player.play()
        }
      default:
        break
      }
    }
  }

  private func showErrorDialog(_ error: Error) {
    guard let currentItem = player?.currentItem,
          let asset = currentItem.asset as? AVURLAsset else {
      return
    }

    showDialog(title: "Error playing audio",
               message: "\(error.localizedDescription)\nURL: \(asset.url)")
  }

  private func showOfflineDialog() {
    showDialog(title: "Audio not available offline",
               message: "Download audio in Settings when you're back online")
  }

  private func showDialog(title: String, message: String) {
    let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
    ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

    let vc = UIApplication.shared.keyWindow!.rootViewController!
    vc.present(ac, animated: true, completion: nil)
  }

  private func itemFinishedPlaying() {
    currentState = .finished
  }
}
