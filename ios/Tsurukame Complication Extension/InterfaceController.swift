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

class InterfaceController: WKInterfaceController {
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    // Configure interface objects here.
  }

  override func willActivate() {
    // This method is called when watch view controller is about to be visible to user
    super.willActivate()

    let userInfo = DataManager.sharedInstance.latestData
    os_log("MZS - user info at UI display time: %{public}@", userInfo ?? "none")
  }

  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
  }
}
