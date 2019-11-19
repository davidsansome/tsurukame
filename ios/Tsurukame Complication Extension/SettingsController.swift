// Copyright 2019 David Sansome
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
import os
import WatchKit

class SettingsController: WKInterfaceController {
  @IBOutlet var dataSourcePicker: WKInterfacePicker!
  let dataSourceOptions: [(String, String)] = [
    ("reviewCount", "Review Counts"),
    ("level", "Level"),
  ]

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    let pickerOptions = dataSourceOptions.map { (caption, title) -> WKPickerItem in
      let pickerItem = WKPickerItem()
      pickerItem.caption = caption
      pickerItem.title = title
      return pickerItem
    }
    // Configure interface objects here.
    dataSourcePicker.setItems(pickerOptions)
  }

  override func willActivate() {}

  @IBAction func onPickerSelect(value: Int) {
    let selected = dataSourceOptions[value]
    os_log("MZS - selected %{public}@", selected.1)
  }
}
