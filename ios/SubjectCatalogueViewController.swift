// Copyright 2026 David Sansome
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
import UIKit

class SubjectCatalogueViewController: UIPageViewController, UIPageViewControllerDelegate,
  UIPageViewControllerDataSource {
  private var services: TKMServices!
  private var level: Int!
  private var answerButton: ShowAnswersButton!

  func setup(services: TKMServices, level: Int) {
    self.services = services
    self.level = level
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
    dataSource = self

    navigationItem.largeTitleDisplayMode = .always
    answerButton = ShowAnswersButton(isOn: Settings.subjectCatalogueViewShowAnswers)
    answerButton.onChange = { [unowned self] _ in self.answersChanged() }
    let answerItem = UIBarButtonItem(customView: answerButton)
    if #available(iOS 26.0, *) {
      // The pill draws its own background.
      answerItem.hidesSharedBackground = true
    }
    navigationItem.rightBarButtonItem = answerItem

    setViewControllers([createViewController(level: level)!], direction: .forward, animated: false,
                       completion: nil)
    updateNavigationItem()
  }

  private func updateNavigationItem() {
    guard let vc = viewControllers?.first as? SubjectsByLevelViewController else {
      return
    }
    level = vc.level
    navigationItem.title = vc.navigationItem.title
    // The table is in the nested page, so tell the navigation bar which one to follow when it's
    // scrolled.
    setContentScrollView(vc.tableView, for: .top)
  }

  private func answersChanged() {
    guard let vc = viewControllers?.first as? SubjectsByLevelViewController else {
      return
    }
    Settings.subjectCatalogueViewShowAnswers = showAnswers
    vc.setShowAnswers(showAnswers, animated: true)
  }

  var showAnswers: Bool {
    answerButton.isOn
  }

  // Moves to another level when the level's previous or next button is tapped.
  private func showLevel(_ newLevel: Int) {
    guard let vc = createViewController(level: newLevel) else {
      return
    }
    setViewControllers([vc], direction: newLevel < level ? .reverse : .forward, animated: true,
                       completion: nil)
    updateNavigationItem()
  }

  // MARK: - UIPageViewControllerDataSource

  func createViewController(level: Int) -> UIViewController? {
    if level < 1 || level > services.localCachingClient.maxLevelGrantedBySubscription {
      return nil
    }

    let vc = StoryboardScene.SubjectsByLevel.initialScene.instantiate()
    vc.setup(services: services, level: level, showAnswers: showAnswers)
    let maxLevel = services.localCachingClient.maxLevelGrantedBySubscription
    vc.hasPreviousLevel = level > 1
    vc.hasNextLevel = level < maxLevel
    vc.onChangeLevel = { [unowned self] in self.showLevel($0) }
    return vc
  }

  func pageViewController(_: UIPageViewController,
                          viewControllerAfter viewController: UIViewController)
    -> UIViewController? {
    guard let vc = viewController as? SubjectsByLevelViewController else {
      return nil
    }
    return createViewController(level: vc.level + 1)
  }

  func pageViewController(_: UIPageViewController,
                          viewControllerBefore viewController: UIViewController)
    -> UIViewController? {
    guard let vc = viewController as? SubjectsByLevelViewController else {
      return nil
    }
    return createViewController(level: vc.level - 1)
  }

  // MARK: - UIPageViewControllerDelegate

  func pageViewController(_: UIPageViewController, didFinishAnimating finished: Bool,
                          previousViewControllers _: [UIViewController],
                          transitionCompleted completed: Bool) {
    if !finished || !completed {
      return
    }
    updateNavigationItem()
  }

  func pageViewController(_: UIPageViewController,
                          willTransitionTo pendingViewControllers: [UIViewController]) {
    for vc in pendingViewControllers {
      if let vc = vc as? SubjectsByLevelViewController {
        vc.setShowAnswers(showAnswers, animated: false)
      }
    }
  }
}
