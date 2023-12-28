// Copyright 2023 David Sansome
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

protocol TKMViewController {
  var canSwipeToGoBack: Bool { get }
}

class NavigationController: UINavigationController, UINavigationControllerDelegate,
  UIGestureRecognizerDelegate {
  private var isPushingViewController = false

  // A pan gesture recogniser that makes it possible to swipe back from anywhere on the view.
  private var panGestureRecognizer: UIPanGestureRecognizer!

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self

    // Add a new pan gesture recogniser, but copy the targets list from the built-in edge pop
    // recogniser.
    if let popGestureRecognizer = interactivePopGestureRecognizer {
      popGestureRecognizer.delegate = self

      if let targets = popGestureRecognizer.value(forKey: "targets") {
        panGestureRecognizer = UIPanGestureRecognizer()
        panGestureRecognizer.setValue(targets, forKey: "targets")
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
      }
    }
  }

  override var childForStatusBarStyle: UIViewController? {
    topViewController?.childForStatusBarStyle ?? topViewController
  }

  // MARK: - UIViewController

  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    isPushingViewController = true
    super.pushViewController(viewController, animated: animated)
  }

  // MARK: - UIGestureRecognizerDelegate

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == interactivePopGestureRecognizer ||
      gestureRecognizer == panGestureRecognizer {
      if viewControllers.count <= 1 || isPushingViewController {
        return false
      }

      if gestureRecognizer == panGestureRecognizer {
        let velocity = panGestureRecognizer.velocity(in: topViewController?.view)
        if velocity.x < 0 || abs(velocity.y) > abs(velocity.x) {
          return false
        }
      }

      if let topVC = topViewController as? TKMViewController {
        return topVC.canSwipeToGoBack
      }
      return false
    }
    return true
  }

  // MARK: - UINavigationControllerDelegate

  func navigationController(_: UINavigationController, didShow _: UIViewController,
                            animated _: Bool) {
    isPushingViewController = false
  }
}
