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

import Foundation
import MMDrawerController

protocol ReviewMenuDelegate: AnyObject {
  func didTapEndReviewSession(button: UIView)
  func didTapWrapUp()
  func wrapUpCount() -> Int
}

class ReviewContainerViewController: MMDrawerController, ReviewViewControllerDelegate,
  ReviewMenuDelegate {
  var services: TKMServices!
  var reviewVC: ReviewViewController!
  var menuVC: ReviewMenuViewController!

  func setup(with services: TKMServices, items: [ReviewItem]) {
    reviewVC = storyboard!
      .instantiateViewController(withIdentifier: "reviewViewController") as? ReviewViewController
    reviewVC.setup(withServices: services, items: items, showMenuButton: true,
                   showSubjectHistory: true, delegate: self)

    menuVC = storyboard!
      .instantiateViewController(withIdentifier: "reviewMenuViewController") as? ReviewMenuViewController
    menuVC.delegate = self

    centerViewController = reviewVC
    leftDrawerViewController = menuVC
    shouldStretchDrawer = false
    closeDrawerGestureModeMask = .all
    centerHiddenInteractionMode = .none
    setDrawerVisualStateBlock(MMDrawerVisualState.parallaxVisualStateBlock(withParallaxFactor: 1.0))
  }

  override func open(_ drawerSide: MMDrawerSide, animated: Bool,
                     completion: ((Bool) -> Void)?) {
    super.open(drawerSide, animated: animated, completion: completion)
    view.endEditing(true)
  }

  override func closeDrawer(animated: Bool, completion: ((Bool) -> Void)?) {
    super.closeDrawer(animated: animated, completion: completion)
    reviewVC.focusAnswerField()
  }

  // MARK: - ReviewViewControllerDelegate

  func reviewVC(_: ReviewViewController, tappedMenuButton _: UIButton) {
    open(.left, animated: true, completion: nil)
  }

  func reviewVCAllowsCheats(forReviewItem _: ReviewItem) -> Bool { Settings.enableCheats }
  func reviewVCAllowsCustomFonts() -> Bool { true }
  func reviewVCShowsSuccessRate() -> Bool { true }

  func reviewVCFinishedAllReviewItems(_ reviewViewController: ReviewViewController) {
    reviewViewController.performSegue(withIdentifier: "reviewSummary", sender: reviewViewController)
  }

  // MARK: - ReviewMenuDelegate

  func didTapEndReviewSession(button: UIView) {
    if reviewVC.tasksAnsweredCorrectly == 0 {
      navigationController?.popToRootViewController(animated: true)
      return
    }
    let c = UIAlertController(title: "End review session?",
                              message: "You'll lose progress on any half-answered reviews",
                              preferredStyle: UIAlertController.Style.actionSheet)
    c.popoverPresentationController?.sourceView = button
    c.popoverPresentationController?.sourceRect = button.bounds
    c.addAction(UIAlertAction(title: "End review session",
                              style: UIAlertAction.Style.destructive,
                              handler: { _ in self.reviewVC.endReviewSession() }))
    c.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
  }

  func didTapWrapUp() {
    reviewVC.wrappingUp = !reviewVC.wrappingUp
    closeDrawer(animated: true, completion: nil)
  }

  func wrapUpCount() -> Int {
    if reviewVC.wrappingUp { return reviewVC.activeQueueLength }
    return 0
  }
}
