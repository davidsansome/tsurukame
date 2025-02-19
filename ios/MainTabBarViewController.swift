// Copyright 2025 David Sansome
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

class MainTabBarViewController: UITabBarController {
  var services: TKMServices!
  weak var waniKaniTabDelegate: MainWaniKaniTabViewController.Delegate?
  weak var waniKaniViewController: MainWaniKaniTabViewController?
  weak var practiceViewController: MainPracticeTabViewController?

  func setup(services: TKMServices, waniKaniTabDelegate: MainWaniKaniTabViewController.Delegate?) {
    self.services = services
    self.waniKaniTabDelegate = waniKaniTabDelegate
  }

  override func viewDidLoad() {
    if !FeatureFlags.showOtherPracticeModes {
      tabBar.isHidden = true
    }

    view.backgroundColor = .clear
    for vc in viewControllers! {
      switch vc {
      case let vc as MainWaniKaniTabViewController:
        vc.setup(services: services, delegate: waniKaniTabDelegate)
        waniKaniViewController = vc

      case let vc as MainPracticeTabViewController:
        vc.setup(services: services)
        practiceViewController = vc

      default:
        break
      }
    }
  }

  func update() {
    waniKaniViewController?.update()
    practiceViewController?.update()
  }
}
