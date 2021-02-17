// Copyright 2021 David Sansome
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

class LessonsViewController: UIViewController, UIPageViewControllerDataSource,
  UIPageViewControllerDelegate, ReviewViewControllerDelegate {
  private var services: TKMServices!
  private var items: [ReviewItem]!

  private var pageController: UIPageViewController!
  private var currentPageIndex = 0
  private var reviewViewController: ReviewViewController?

  @IBOutlet private var pageControl: LessonsPageControl!
  @IBOutlet private var backButton: UIButton!

  func setup(services: TKMServices, items: [ReviewItem]) {
    self.services = services
    self.items = items
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = TKMStyle.Color.background

    // Create the page controller.
    pageController = UIPageViewController(transitionStyle: .scroll,
                                          navigationOrientation: .horizontal, options: nil)
    pageController.delegate = self
    pageController.dataSource = self

    // Set the subjects on the page control.
    var subjects = [TKMSubject]()
    for item in items {
      if let subject = services.localCachingClient.getSubject(id: item.assignment.subjectID) {
        subjects.append(subject)
      }
    }
    pageControl.setSubjects(subjects)

    // Add it as a child view controller, below the back button.
    addChild(pageController)
    view.insertSubview(pageController.view, belowSubview: backButton)
    pageController.didMove(toParent: self)

    // Hook up the page control.
    pageControl.addTarget(self, action: #selector(pageChanged), for: .valueChanged)

    // Load the first page.
    if let vc = createViewController(index: 0) {
      pageController.setViewControllers([vc], direction: .forward,
                                        animated: false, completion: nil)
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    SiriShortcutHelper.shared.attachShortcutActivity(self, type: .lessons)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let safeArea = view.frame.inset(by: view.tkm_safeAreaInsets)
    let pageControlSize = pageControl.sizeThatFits(CGSize(width: view.frame.size.width, height: 0))
    let pageControlFrame = CGRect(x: safeArea.minX, y: safeArea.maxY - pageControlSize.height,
                                  width: safeArea.size.width,
                                  height: pageControlSize.height)

    pageControl.frame = pageControlFrame
    pageControl.setNeedsLayout()

    var pageControllerFrame = view.frame
    pageControllerFrame.size.height = pageControlFrame.origin.y
    pageController.view.frame = pageControllerFrame
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  @IBAction private func didTapBackButton(sender _: Any) {
    navigationController?.popViewController(animated: true)
  }

  // MARK: - UIPageControl

  @objc func pageChanged() {
    let newPageIndex = pageControl.currentPageIndex
    if newPageIndex == currentPageIndex {
      return
    }

    if let vc = createViewController(index: newPageIndex) {
      let direction: UIPageViewController
        .NavigationDirection = (newPageIndex > currentPageIndex) ? .forward : .reverse
      pageController.setViewControllers([vc], direction: direction, animated: true, completion: nil)
      currentPageIndex = newPageIndex
    }
  }

  // MARK: - UIPageViewControllerDelegate

  func pageViewController(_: UIPageViewController, didFinishAnimating _: Bool,
                          previousViewControllers _: [UIViewController],
                          transitionCompleted _: Bool) {
    let index = indexOf(viewController: pageController.viewControllers![0])
    pageControl.currentPageIndex = index
    currentPageIndex = index
  }

  // MARK: - UIPageViewControllerDataSource

  private func createViewController(index: Int) -> UIViewController? {
    if index == items.count {
      if reviewViewController == nil {
        reviewViewController = storyboard!
          .instantiateViewController(withIdentifier: "reviewViewController") as? ReviewViewController
        reviewViewController?.setup(services: services, items: items, showMenuButton: false,
                                    showSubjectHistory: false, delegate: self)
      }
      return reviewViewController
    } else if index < 0 || index > items.count {
      return nil
    }

    let item = items[index]
    if let subject = services.localCachingClient.getSubject(id: item.assignment.subjectID) {
      let vc = storyboard?
        .instantiateViewController(withIdentifier: "subjectDetailsViewController") as! SubjectDetailsViewController
      vc.setup(services: services, subject: subject, showHints: true, hideBackButton: true,
               index: index)
      return vc
    }
    return nil
  }

  private func indexOf(viewController: UIViewController) -> Int {
    if let viewController = viewController as? SubjectDetailsViewController {
      return viewController.index
    } else if viewController is ReviewViewController {
      return items.count
    }
    return 0
  }

  func pageViewController(_: UIPageViewController,
                          viewControllerAfter viewController: UIViewController)
    -> UIViewController? {
    createViewController(index: indexOf(viewController: viewController) + 1)
  }

  func pageViewController(_: UIPageViewController,
                          viewControllerBefore viewController: UIViewController)
    -> UIViewController? {
    createViewController(index: indexOf(viewController: viewController) - 1)
  }

  // MARK: - ReviewViewControllerDelegate

  func reviewViewControllerAllowsCheats(forReviewItem _: ReviewItem) -> Bool {
    false
  }

  func reviewViewControllerFinishedAllReviewItems(_ reviewViewController: ReviewViewController) {
    reviewViewController.navigationController?.popToRootViewController(animated: true)
  }

  func reviewViewControllerAllowsCustomFonts() -> Bool {
    false
  }

  func reviewViewControllerShowsSuccessRate() -> Bool {
    false
  }

  // MARK: - Keyboard navigation

  override var canBecomeFirstResponder: Bool {
    true
  }

  override var keyCommands: [UIKeyCommand]? {
    // No keyboard nav on the quiz page, answer the quiz.
    if pageControl.currentPageIndex == items.count {
      return []
    }

    return [
      UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [],
                   action: #selector(prevPage),
                   discoverabilityTitle: "Previous"),
      UIKeyCommand(input: "a", modifierFlags: [], action: #selector(prevPage)),
      UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [],
                   action: #selector(nextPage),
                   discoverabilityTitle: "Next"),
      UIKeyCommand(input: "d", modifierFlags: [], action: #selector(nextPage)),
      UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(nextPage)),
      UIKeyCommand(input: " ", modifierFlags: [], action: #selector(playAudio),
                   discoverabilityTitle: "Play reading"),
      UIKeyCommand(input: "j", modifierFlags: [], action: #selector(playAudio)),
      UIKeyCommand(input: "q", modifierFlags: [], action: #selector(jumpToQuiz),
                   discoverabilityTitle: "Jump to quiz"),
    ]
  }

  @objc func prevPage() {
    if pageControl.currentPageIndex > 0 {
      pageControl.currentPageIndex -= 1
      pageChanged()
    }
  }

  @objc func nextPage() {
    if pageControl.currentPageIndex < items.count {
      pageControl.currentPageIndex += 1
      pageChanged()
    }
  }

  @objc func jumpToQuiz() {
    pageControl.currentPageIndex = items.count
    pageChanged()
  }

  @objc func playAudio() {
    if let vc = pageController.viewControllers?.first as? SubjectDetailsViewController {
      vc.playAudio()
    }
  }
}
