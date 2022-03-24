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

import PromiseKit
import UIKit

class OfflineAudioViewController: UITableViewController {
  private var services: TKMServices!
  private var model: TableModel!

  private var statusIndex: IndexPath?
  private var sizeIndex: IndexPath?

  func setup(services: TKMServices) {
    self.services = services
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    progress = services.offlineAudio.lastProgress
    rerender()
  }

  private func rerender() {
    let model = MutableTableModel(tableView: tableView, delegate: nil)
    let enabled = Settings.offlineAudio

    model.add(section: "", footer: """
    Download audio to your \(UIDevice.current.model) so it plays without \
    delay online and it's available when you're not connected to the Internet.
    """)
    model.add(SwitchModelItem(style: .default, title: "Enable offline audio", subtitle: nil,
                              on: enabled, switchHandler: toggleOfflineAudio))

    let cellularItem = SwitchModelItem(style: .default, title: "Download over cellular",
                                       subtitle: nil, on: Settings.offlineAudioCellular,
                                       switchHandler: toggleCellular)
    cellularItem.isEnabled = enabled
    model.add(cellularItem)

    // Create the list of voice actors.
    model.add(section: "Voice actors")
    for voiceActor in services.localCachingClient.getVoiceActors() {
      let title = voiceActor.name
      var subtitle = voiceActor.description_p
      switch voiceActor.gender {
      case .male:
        subtitle += " - male"
      case .female:
        subtitle += " - female"
      default:
        break
      }

      let id = voiceActor.id
      let on = Settings.offlineAudioVoiceActors.contains(id)
      let item = SwitchModelItem(style: .subtitle,
                                 title: title,
                                 subtitle: subtitle,
                                 on: on) { [unowned self] (on: Bool) in
        self.toggleVoiceActor(voiceActorId: id, on: on)
      }
      item.isEnabled = enabled
      model.add(item)
    }

    model.add(section: "Status", footer: "Downloads will continue in the background")
    statusIndex = model
      .add(BasicModelItem(style: .value1, title: statusTitle, subtitle: statusSubtitle))
    sizeIndex = model.add(BasicModelItem(style: .value1, title: "Cache size",
                                         subtitle: "..."))

    self.model = model
    model.reloadTable()

    updateCacheSize()
  }

  private func toggleOfflineAudio(on: Bool) {
    Settings.offlineAudio = on

    if on {
      // Select all voice actors if there are none selected already.
      if Settings.offlineAudioVoiceActors.isEmpty {
        for voiceActor in services.localCachingClient.getVoiceActors() {
          Settings.offlineAudioVoiceActors.insert(voiceActor.id)
        }
      }
    }

    settingsChanged()
    rerender()

    if !on {
      // Ask the user if they want to delete audio that's downloaded already.
      let device = UIDevice.current.model
      let ac = UIAlertController(title: "Delete offline audio?",
                                 message: "Free up space on your \(device)? You can download it again later",
                                 preferredStyle: .alert)
      ac.addAction(UIAlertAction(title: "Keep", style: .cancel, handler: nil))
      ac.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
        firstly {
          self.services.offlineAudio.deleteAll()
        }.ensure {
          self.updateCacheSize()
        }.catch { _ in }
      })
      present(ac, animated: true, completion: nil)
    }
  }

  private func toggleCellular(on: Bool) {
    Settings.offlineAudioCellular = on
    settingsChanged()
  }

  private func toggleVoiceActor(voiceActorId: Int64, on: Bool) {
    if on {
      Settings.offlineAudioVoiceActors.insert(voiceActorId)
    } else {
      Settings.offlineAudioVoiceActors.remove(voiceActorId)
    }
    settingsChanged()
  }

  private func settingsChanged() {
    progress = services.offlineAudio.queueDownloads()
  }

  private var progressObservers = [NSKeyValueObservation]()
  private var progress: Progress? {
    didSet {
      // Remove any observers created last time.
      progressObservers.forEach { $0.invalidate() }
      progressObservers.removeAll()

      // Update the UI with the current progress.
      updateProgress()

      // Observe changes to the new progress object.
      if let progress = progress {
        func observeProgressValue<Value>(_ kp: KeyPath<Progress, Value>) {
          progressObservers
            .append(progress.observe(kp, options: []) { _, _ in self.updateProgress() })
        }
        observeProgressValue(\.totalUnitCount)
        observeProgressValue(\.fractionCompleted)
      }
    }
  }

  private var isProgressActive: Bool {
    progress != nil && !progress!.isFinished && progress!.totalUnitCount != 0
  }

  private func cacheDirectorySize() -> Promise<String> {
    firstly {
      services.offlineAudio.cacheDirectorySize()
    }.map { sizeBytes in
      ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
  }

  private var statusTitle: String {
    if isProgressActive {
      return "Downloading audio..."
    }
    return "Up to date"
  }

  private var statusSubtitle: String? {
    if let progress = progress, isProgressActive {
      return String(Int(progress.fractionCompleted * 100)) + "%"
    }
    return nil
  }

  private func updateProgress() {
    guard let statusIndex = statusIndex else {
      return
    }

    // Calculating the cache directory size is expensive - only do it if we've finished downloading
    // everything.
    if !isProgressActive {
      updateCacheSize()
    }

    DispatchQueue.main.async {
      if let statusCell = self.tableView.cellForRow(at: statusIndex) as? BasicModelCell,
         let item = statusCell.item as? BasicModelItem {
        item.title = self.statusTitle
        item.subtitle = self.statusSubtitle
        statusCell.textLabel?.text = item.title
        statusCell.detailTextLabel?.text = item.subtitle
      }
    }
  }

  private func updateCacheSize() {
    guard let sizeIndex = sizeIndex else {
      return
    }

    firstly {
      cacheDirectorySize()
    }.done { sizeLabel in
      DispatchQueue.main.async {
        if let sizeCell = self.tableView.cellForRow(at: sizeIndex) as? BasicModelCell,
           let item = sizeCell.item as? BasicModelItem {
          item.subtitle = sizeLabel
          sizeCell.detailTextLabel?.text = sizeLabel
        }
      }
    }.catch { _ in }
  }
}
