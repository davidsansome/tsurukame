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
import MMDrawerController

class ReviewContainerViewController: MMDrawerController, ReviewViewControllerDelegate,
  ReviewQuickSettingsMenuDelegate {
  var services: TKMServices!
  var reviewVC: ReviewViewController!

  func setup(services: TKMServices, items: [ReviewItem], isPracticeSession: Bool = false) {
    self.services = services

    reviewVC = StoryboardScene.Review.initialScene.instantiate()
    reviewVC.setup(services: services, items: items, showMenuButton: true, showSubjectHistory: true,
                   delegate: self, isPracticeSession: isPracticeSession)

    let menuVC = ReviewQuickSettingsMenu(services: services, delegate: self)
    let menuNavigationVC = UINavigationController(rootViewController: menuVC)
    menuNavigationVC.navigationBar.tintColor = .white

    centerViewController = reviewVC
    leftDrawerViewController = menuNavigationVC
    shouldStretchDrawer = false
    closeDrawerGestureModeMask = .all
    openDrawerGestureModeMask = .bezelPanningCenterView
    centerHiddenInteractionMode = .none
    setDrawerVisualStateBlock(MMDrawerVisualState.parallaxVisualStateBlock(withParallaxFactor: 1.0))
  }

  override func setAnimatingDrawer(_ animatingDrawer: Bool) {
    super.setAnimatingDrawer(animatingDrawer)

    // Hide the keyboard if we're opening the drawer, show it if we're closing it.
    if (animatingDrawer && openSide == .none) ||
      (!animatingDrawer && openSide != .none) {
      view.endEditing(true)
    } else if animatingDrawer, openSide != .none {
      reviewVC.focusAnswerField()
    }
  }

  // MARK: - UIViewController

  override func viewWillAppear(_ animated: Bool) {
    if isInSettingsVc {
      isInSettingsVc = false
      closeDrawer(animated: false, completion: nil)
    }
    super.viewWillAppear(animated)
  }

  // MARK: - ReviewViewControllerDelegate

  func allowsCheats(forReviewItem _: ReviewItem) -> Bool {
    Settings.enableCheats
  }

  func tappedMenuButton(reviewViewController _: ReviewViewController, menuButton _: UIButton) {
    (leftDrawerViewController as! UINavigationController).popToRootViewController(animated: false)
    open(.left, animated: true, completion: nil)
  }

  func finishedAllReviewItems(_ reviewViewController: ReviewViewController) {
    reviewViewController.perform(segue: StoryboardSegue.Review.reviewSummary,
                                 sender: reviewViewController)
  }

  func allowsCustomFonts() -> Bool {
    true
  }

  func showsSuccessRate() -> Bool {
    true
  }

  // MARK: - ReviewMenuDelegate

  // Set to true when another settings view controller is pushed. Upon returning to
  // this view controller, the ReviewViewController will reload its display.
  var isInSettingsVc = false

  func closeMenuAndPush(viewController: UIViewController) {
    isInSettingsVc = true
    navigationController?.pushViewController(viewController, animated: true)
  }

  func quickSettingsChanged() {
    reviewVC.quickSettingsChanged()
  }

  func endReviewSession(button: UIView) {
    if reviewVC.tasksAnsweredCorrectly == 0 || !reviewVC.canWrapUp {
      navigationController?.popToRootViewController(animated: true)
      return
    }

    let ac = UIAlertController(title: "End review session?",
                               message: "You'll lose progress on any half-answered reviews",
                               preferredStyle: .actionSheet)
    ac.popoverPresentationController?.sourceView = button
    ac.popoverPresentationController?.sourceRect = button.bounds

    ac.addAction(UIAlertAction(title: "End review session", style: .destructive) { _ in
      self.reviewVC.endReviewSession()
    })
    ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(ac, animated: true)
  }

  func canWrapUp() -> Bool {
    reviewVC.canWrapUp
  }

  func wrapUp() {
    reviewVC.wrappingUp = !reviewVC.wrappingUp
    closeDrawer(animated: true, completion: nil)
  }

  func wrapUpCount() -> Int {
    if reviewVC.wrappingUp {
      return reviewVC.activeQueueLength
    }
    return 0
  }
}
