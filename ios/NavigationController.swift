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

    // Large titles are only shown by screens that ask for them (the settings pages); see
    // navigationController(_:willShow:animated:). Their font is set on the appearances because the
    // bar's own largeTitleTextAttributes lose the weight when switching between light and dark.
    navigationBar.prefersLargeTitles = true
    let largeTitleAttributes: [NSAttributedString.Key: Any] = [
      .font: largeTitleFont(),
      .foregroundColor: TKMStyle.Color.label,
    ]
    let standard = navigationBar.standardAppearance.copy()
    standard.largeTitleTextAttributes = largeTitleAttributes
    navigationBar.standardAppearance = standard
    let scrollEdge = standard.copy()
    scrollEdge.configureWithTransparentBackground()
    scrollEdge.largeTitleTextAttributes = largeTitleAttributes
    navigationBar.scrollEdgeAppearance = scrollEdge

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

    NavigationController.shared = self
    let saved = UserDefaults.standard.double(forKey: NavigationController.kZoomScaleKey)
    if saved >= 0.5 {
      zoomScale = CGFloat(saved)
    }
  }

  // MARK: - UI Zoom

  weak static var shared: NavigationController?

  private static let kZoomScaleKey = "ui_zoom_scale"
  private(set) var zoomScale: CGFloat = 1.0 {
    didSet {
      UserDefaults.standard.set(Double(zoomScale), forKey: NavigationController.kZoomScaleKey)
      applyZoom()
      NotificationCenter.default.post(name: .zoomScaleDidChange, object: nil)
    }
  }

  @objc func zoomIn() {
    zoomScale = min(zoomScale + 0.15, 2.0)
  }

  @objc func zoomOut() {
    zoomScale = max(zoomScale - 0.15, 0.75)
  }

  @objc func zoomReset() {
    zoomScale = 1.0
  }

  func applyZoom() {
    guard let window = view.window else { return }

    let winSize = window.bounds.size
    if abs(zoomScale - 1.0) < 0.001 {
      if view.transform != .identity {
        view.transform = .identity
      }
      if view.frame != window.bounds {
        view.frame = window.bounds
      }
      return
    }

    let targetBounds = CGRect(x: 0, y: 0, width: winSize.width / zoomScale,
                              height: winSize.height / zoomScale)
    let targetTransform = CGAffineTransform(scaleX: zoomScale, y: zoomScale)
    let targetCenter = CGPoint(x: winSize.width / 2.0, y: winSize.height / 2.0)

    if view.bounds != targetBounds {
      view.bounds = targetBounds
    }
    if view.transform != targetTransform {
      view.transform = targetTransform
    }
    if view.center != targetCenter {
      view.center = targetCenter
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if abs(zoomScale - 1.0) >= 0.001 {
      applyZoom()
    }
  }

  override var keyCommands: [UIKeyCommand]? {
    var commands = super.keyCommands ?? []
    commands.append(contentsOf: [
      UIKeyCommand(input: "+", modifierFlags: .command, action: #selector(zoomIn),
                   discoverabilityTitle: "Zoom In"),
      UIKeyCommand(input: "-", modifierFlags: .command, action: #selector(zoomOut),
                   discoverabilityTitle: "Zoom Out"),
      UIKeyCommand(input: "0", modifierFlags: .command, action: #selector(zoomReset),
                   discoverabilityTitle: "Actual Size"),
    ])
    return commands
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

  func navigationController(_: UINavigationController, willShow viewController: UIViewController,
                            animated _: Bool) {
    if viewController.navigationItem.largeTitleDisplayMode == .automatic {
      viewController.navigationItem.largeTitleDisplayMode = .never
    }
  }

  func navigationController(_: UINavigationController, didShow _: UIViewController,
                            animated _: Bool) {
    isPushingViewController = false
  }
}

extension Notification.Name {
  static let zoomScaleDidChange = Notification.Name("zoomScaleDidChange")
}
