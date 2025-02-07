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
import PromiseKit
import WaniKaniAPI

private let kDefaultProfileImageURL =
  "https://cdn.wanikani.com/default-avatar-300x300-20121121.png"
private let kProfileImageSize: CGFloat = 80

private let kUpcomingReviewsSection = 1

private func userProfileImageURL(emailAddress: String) -> URL {
  let address = emailAddress.trimmingCharacters(in: .whitespaces).lowercased()
  // Gravatar asks for an SHA-256 hash: https://docs.gravatar.com/general/hash/
  let hash = address.sha256()

  let size = kProfileImageSize * UIScreen.main.scale

  return URL(string: "https://www.gravatar.com/avatar/\(hash).jpg?s=\(size)&d=\(kDefaultProfileImageURL)")!
}

class MainViewController: UIViewController, LoginViewControllerDelegate,
  SearchResultViewControllerDelegate, UISearchControllerDelegate,
  UITableViewDelegate, MainWaniKaniTabViewController.Delegate {
  var services: TKMServices!

  @IBOutlet var titleView: MainTitleView!
  @IBOutlet var vacationView: VacationModeView!
  @IBOutlet var progressView: UIProgressView!
  @IBOutlet var headerGradient: GradientView!

  var searchController: UISearchController!
  weak var searchResultsViewController: SearchResultViewController!
  weak var tabBarViewController: MainTabBarViewController?

  var hourlyRefreshTimer = Timer()
  var isShowingUnauthorizedAlert = false
  var isUpdating = false

  private let nd = NotificationDispatcher()

  func setup(services: TKMServices) {
    self.services = services
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Create the search results view controller.
    let searchResultsVC = StoryboardScene.SearchResult.initialScene.instantiate()
    searchResultsVC.setup(services: services, delegate: self)
    searchResultsViewController = searchResultsVC

    // Create the search controller.
    searchController = UISearchController(searchResultsController: searchResultsViewController)
    searchController.searchResultsUpdater = searchResultsViewController
    searchController.delegate = self

    // Configure the search bar.
    let searchBar = searchController.searchBar
    searchBar.barTintColor = TKMStyle.radicalColor2
    searchBar.autocapitalizationType = .none

    let originalSearchBarTintColor = searchBar.tintColor
    searchBar.tintColor = .white // Make the button white.

    if #available(iOS 13, *) {
      let searchTextField = searchBar.searchTextField
      searchTextField.backgroundColor = .systemBackground
      searchTextField.tintColor = originalSearchBarTintColor
    } else {
      for view in searchBar.subviews[0].subviews {
        if view.isKind(of: UITextField.self) {
          // Make the input field cursor dark blue.
          view.tintColor = originalSearchBarTintColor
        }
      }
    }

    updateGradientColors()
    updateHourlyTimer()
    recreateTableModel()

    nd.add(name: .lccAvailableItemsChanged) { [weak self] _ in self?.availableItemsChanged() }
    nd.add(name: .lccRecentMistakesCountChanged) { [weak self] _ in self?.availableItemsChanged() }
    nd.add(name: .lccUserInfoChanged) { [weak self] _ in self?.userInfoChanged() }
    nd.add(name: .lccSRSCategoryCountsChanged) { [weak self] _ in self?.srsLevelCountsChanged() }
    nd.add(name: .lccUnauthorized) { [weak self] _ in self?.clientIsUnauthorized() }
    nd
      .add(name: UIApplication.didEnterBackgroundNotification) { [weak self] _ in
        self?.applicationDidEnterBackground()
      }
    nd
      .add(name: UIApplication.willEnterForegroundNotification) { [weak self] _ in
        self?.applicationWillEnterForeground()
      }
  }

  private func updateGradientColors() {
    headerGradient.colors = TKMStyle.radicalGradient
  }

  private func scheduleTableModelUpdate() {
    if isUpdating {
      return
    }
    isUpdating = true

    DispatchQueue.main.async {
      WatchHelper.sharedInstance.updatedData(client: self.services.localCachingClient)
      self.isUpdating = false
      self.recreateTableModel()
    }
  }

  private func recreateTableModel() {
    updateUserInfo()

    tabBarViewController?.update()
  }

  // MARK: - UIViewController

  override func viewWillAppear(_ animated: Bool) {
    // Assume the hour changed while the view was invisible. This will invalidate the upcoming
    // review cache which depends on the current time.
    services.localCachingClient.currentHourChanged()

    updateHourlyTimer()

    navigationController?.isNavigationBarHidden = false

    if #available(iOS 15.0, *) {} else {
      if let bar = navigationController?.navigationBar {
        bar.setBackgroundImage(UIImage(), for: .default)
        bar.shadowImage = UIImage()
        bar.isTranslucent = true
      }
    }

    super.viewWillAppear(animated)
  }

  override func viewDidAppear(_: Bool) {
    // Only start refreshing after the user has finished swiping back to this view.
    refresh(quick: true)
  }

  override func viewWillDisappear(_ animated: Bool) {
    if #available(iOS 15.0, *) {} else {
      if let bar = navigationController?.navigationBar {
        bar.setBackgroundImage(nil, for: .default)
        bar.shadowImage = nil
        bar.isTranslucent = false
      }
    }

    super.viewWillDisappear(animated)
    cancelHourlyTimer()
  }

  override func viewDidLayoutSubviews() {
    updateTableContentInset(animated: false)
    // Scroll to the very top, including the inset.
    // TODO:
    // tableView.contentOffset = CGPoint(x: 0, y: -tableView.contentInset.top)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func traitCollectionDidChange(_: UITraitCollection?) {
    updateGradientColors()
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.Main(segue) {
    case .embedTabBar:
      let vc = segue.destination as! MainTabBarViewController
      vc.setup(services: services, waniKaniTabDelegate: self)

      tabBarViewController = vc

    case .settings:
      let vc = segue.destination as! SettingsViewController
      vc.setup(services: services)

    default:
      break
    }
  }

  // MARK: - Navigation bar buttons

  @IBAction func searchButtonTapped() {
    present(searchController, animated: true, completion: nil)
  }

  @IBAction func settingsButtonTapped() {
    perform(segue: StoryboardSegue.Main.settings, sender: self)
  }

  // MARK: - Refresh on the hour in the foreground

  func updateHourlyTimer() {
    cancelHourlyTimer()

    let calendar = Calendar.current as NSCalendar
    let date = calendar
      .nextDate(after: Date(), matching: .minute, value: 0, options: .matchNextTime)!

    hourlyRefreshTimer = Timer.scheduledTimer(withTimeInterval: date.timeIntervalSinceNow,
                                              repeats: false,
                                              block: { [weak self] _ in
                                                guard let self = self else { return }
                                                self.hourlyTimerExpired()
                                              })
  }

  func cancelHourlyTimer() {
    hourlyRefreshTimer.invalidate()
    hourlyRefreshTimer = Timer()
  }

  func hourlyTimerExpired() {
    services.localCachingClient.currentHourChanged()
    refresh(quick: true)
    updateHourlyTimer()
  }

  func applicationDidEnterBackground() {
    cancelHourlyTimer()
  }

  func applicationWillEnterForeground() {
    // Assume the hour changed while the application was in the background. This will invalidate the
    // upcoming review cache which depends on the current time.
    services.localCachingClient.currentHourChanged()

    updateHourlyTimer()
  }

  // MARK: - Refreshing contents

  func refresh(quick: Bool) {
    let progress = Progress(totalUnitCount: 0)
    let syncFuture = services.localCachingClient.sync(quick: quick, progress: progress)

    setProgress(progress)

    if quick {
      scheduleTableModelUpdate()
    } else {
      if !progress.isFinished,
         let overlay = FullRefreshOverlayView(window: view.window!) {
        syncFuture.finally {
          overlay.hide()
        }
      }
    }
  }

  var progressKvoToken: NSKeyValueObservation?
  func setProgress(_ progress: Progress) {
    guard progressView != nil, !progress.isFinished else { return }

    // Set the progress on the progress view and fade it in.
    progressView.observedProgress = progress
    UIView.animate(withDuration: 0.2) {
      self.progressView.alpha = 1.0
    }

    // Wait for the progress to finish.
    progressKvoToken?.invalidate()
    progressKvoToken = progress.observe(\.isFinished, options: [.new]) { _, change in
      if let isFinished = change.newValue, isFinished {
        self.progressKvoToken?.invalidate()

        UIView.animate(withDuration: 0.6) {
          self.progressView.alpha = 0.0
        }
      }
    }
  }

  func availableItemsChanged() {
    if (view?.window) != nil {
      scheduleTableModelUpdate()
    }
  }

  func userInfoChanged() {
    updateUserInfo()
  }

  func updateUserInfo() {
    guard let user = services.localCachingClient.getUserInfo() else { return }
    let email = Settings.gravatarCustomEmail.isEmpty
      ? Settings.userEmailAddress : Settings.gravatarCustomEmail
    let guruKanji = services.localCachingClient.guruKanjiCount
    let imageURL = email.isEmpty ? URL(string: kDefaultProfileImageURL)
      : userProfileImageURL(emailAddress: email)

    titleView.update(username: user.username,
                     level: Int(user.level),
                     guruKanji: Int(guruKanji),
                     imageURL: imageURL)

    updateTableContentInset(animated: true)
  }

  func updateTableContentInset(animated: Bool) {
    guard let user = services.localCachingClient.getUserInfo() else { return }

    var top: CGFloat = 0.0
    var vacationAlpha: CGFloat = 0.0
    if user.hasVacationStartedAt {
      top += vacationView.frame.height
      vacationAlpha = 1.0
    }

    let animations = {
      // TODO:
      // self.tableView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
      self.vacationView.alpha = vacationAlpha
    }
    if animated {
      UIView.animate(withDuration: 0.3, animations: animations)
    } else {
      animations()
    }
  }

  func srsLevelCountsChanged() {
    if (view?.window) != nil {
      updateUserInfo()
      scheduleTableModelUpdate()
    }
  }

  func clientIsUnauthorized() {
    if isShowingUnauthorizedAlert {
      return
    }
    isShowingUnauthorizedAlert = true

    let ac = UIAlertController(title: "Logged out",
                               message: "Your API token expired, is invalid, or does not have the proper permissions. Please log in again. You won't lose your review progress.\n\nAPI tokens for the Tsurukame app cannot be expired and require all of the following permissions: assignments:start, reviews:create, study_materials:create, study_materials:update.",
                               preferredStyle: .alert)

    if Settings.userApiToken != "" {
      ac.addAction(UIAlertAction(title: "Manage tokens on WaniKani", style: .default,
                                 handler: { _ in
                                   self.loginAgain()
                                   if let link =
                                     URL(string: "https://www.wanikani.com/settings/personal_access_tokens#" +
                                       Settings
                                       .userApiToken) {
                                     UIApplication.shared.open(link)
                                   }
                                 }))
    }
    ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
      self.loginAgain()
    }))
    present(ac, animated: true, completion: nil)
  }

  func loginAgain() {
    guard services.localCachingClient.getUserInfo() != nil else {
      return
    }

    let vc = StoryboardScene.Login.initialScene.instantiate()
    vc.delegate = self
    if !Settings.userEmailAddress.isEmpty {
      vc.forcedEmail = Settings.userEmailAddress
    } else {
      vc.forcedEmail = nil
    }
    navigationController?.pushViewController(vc, animated: true)
  }

  func loginComplete() {
    services.localCachingClient.client.updateApiToken(Settings.userApiToken)
    navigationController?.popViewController(animated: true)
    isShowingUnauthorizedAlert = false
  }

  // MARK: - MainWaniKaniTabViewController.Delegate

  func didPullToRefresh() {
    refresh(quick: false)
  }

  // MARK: - Search

  func searchResultSelected(subject: TKMSubject) {
    let vc = StoryboardScene.SubjectDetails.initialScene.instantiate()
    vc.setup(services: services, subject: subject, showHints: true, hideBackButton: false, index: 0)
    searchController.dismiss(animated: true) {
      self.navigationController?.pushViewController(vc, animated: true)
    }
  }
}
