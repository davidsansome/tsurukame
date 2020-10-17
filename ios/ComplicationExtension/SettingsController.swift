// Copyright 2020 David Sansome
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

import ClockKit
import Foundation
import os
import WatchKit

class SettingsController: WKInterfaceController, DataManagerDelegate {
  @IBOutlet var updateAgeTimer: WKInterfaceTimer!
  @IBOutlet var updateAgeHeader: WKInterfaceLabel!
  @IBOutlet var dataSourcePicker: WKInterfacePicker!
  @IBOutlet var staleDataWarning: WKInterfaceLabel!

  let dataSourceOptions: [(ComplicationDataSource, String)] = [
    (.ReviewCounts, "Review Counts"),
    (.Level, "Level"),
    // Removed pending real data
    // (.Character, "Kanji"),
  ]

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    let pickerOptions = dataSourceOptions.map { (_, title) -> WKPickerItem in
      let pickerItem = WKPickerItem()
      pickerItem.caption = title
      pickerItem.title = title
      return pickerItem
    }
    // Configure interface objects here.
    dataSourcePicker.setItems(pickerOptions)

    for (idx, (dataSource, _)) in dataSourceOptions.enumerated() {
      if dataSource == DataManager.sharedInstance.dataSource {
        dataSourcePicker.setSelectedItemIndex(idx)
      }
    }
  }

  override func willActivate() {
    if let userInfo = DataManager.sharedInstance.latestData {
      onDataUpdated(data: userInfo, dataSource: DataManager.sharedInstance.dataSource)
    } else {
      updateAgeHeader.setText("Open app to update")
      updateAgeTimer.setHidden(true)
    }

    DataManager.sharedInstance.addDelegate(self)
  }

  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
    DataManager.sharedInstance.removeDelegate(self)

    // If we've been viewing settings make sure we refresh complication
    // on return.
    let server = CLKComplicationServer.sharedInstance()
    if let complications = server.activeComplications {
      for complication in complications {
        server.reloadTimeline(for: complication)
      }
    }
  }

  // MARK: - DataManagerDelegate

  func onDataUpdated(data: UserData, dataSource _: ComplicationDataSource) {
    if let sentAtSecs = data[WatchHelper.keySentAt] as? EpochTimeInt {
      updateAgeHeader.setText("Last Updated")
      updateAgeTimer.setHidden(false)
      let date = Date(timeIntervalSince1970: TimeInterval(sentAtSecs))
      updateAgeTimer.setDate(date)
      updateAgeTimer.start()

      if DataManager.sharedInstance.dataIsStale() {
        staleDataWarning.setHidden(false)
      } else {
        staleDataWarning.setHidden(true)
      }
    } else {
      updateAgeHeader.setText("No data, open app to update")
      updateAgeTimer.setHidden(true)
      staleDataWarning.setHidden(true)
    }
  }

  @IBAction func onPickerSelect(value: Int) {
    let selected = dataSourceOptions[value]
    DataManager.sharedInstance.dataSource = selected.0
  }
}
