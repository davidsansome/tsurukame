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
import PromiseKit
import WaniKaniAPI

private let kDefaultProfileImageURL =
  "https://cdn.wanikani.com/default-avatar-300x300-20121121.png"
private let kProfileImageSize: CGFloat = 80

private let kUpcomingReviewsSection = 1

private func userProfileImageURL(emailAddress: String) -> URL {
  let address = emailAddress.trimmingCharacters(in: .whitespaces).lowercased()
  let hash = address.MD5()

  let size = kProfileImageSize * UIScreen.main.scale

  return URL(string: "https://www.gravatar.com/avatar/\(hash).jpg?s=\(size)&d=\(kDefaultProfileImageURL)")!
}

private func setTableViewCellCount(_ item: BasicModelItem, count: Int,
                                   disabledMessage: String? = nil) -> Bool {
  item.subtitle = count < 0 ? "-" : "\(count)"
  item.isEnabled = count > 0 && (disabledMessage == nil)

  if let message = disabledMessage {
    item.title = "\(item.title!) (\(message))"
  }

  return item.isEnabled
}

class MainViewController: UIViewController, LoginViewControllerDelegate,
  SearchResultViewControllerDelegate, UISearchControllerDelegate, UITableViewDelegate {
  var services: TKMServices!
  var model: TableModel!
  @IBOutlet var titleView: MainTitleView!
  @IBOutlet var vacationView: VacationModeView!
  @IBOutlet var progressView: UIProgressView!
  @IBOutlet var tableView: UITableView!
  @IBOutlet var headerGradient: GradientView!

  var searchController: UISearchController!
  weak var searchResultsViewController: SearchResultViewController!
  var hourlyRefreshTimer = Timer()
  var isShowingUnauthorizedAlert = false
  var hasLessons = false
  var hasReviews = false
  var updatingTableModel = false

  var selectedSubjectCatalogLevel = -1

  private let nd = NotificationDispatcher()

  func setup(services: TKMServices) {
    self.services = services
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.delegate = self

    // Show a background image.
    let backgroundView = UIImageView(image: UIImage(named: "launch_screen"))
    backgroundView.alpha = 0.25
    tableView.backgroundView = backgroundView

    // Add a refresh control for when the user pulls down.
    let refreshControl = UIRefreshControl()
    refreshControl.tintColor = TKMStyle.Color.label
    refreshControl.backgroundColor = nil
    refreshControl.attributedTitle = NSMutableAttributedString(string: "Pull to refresh...")
    refreshControl.addAction(for: .valueChanged) { [weak self] in self?.didPullToRefresh() }
    tableView.refreshControl = refreshControl

    // Create the search results view controller.
    let searchResultsVC = storyboard?
      .instantiateViewController(withIdentifier: "searchResults") as! SearchResultViewController
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

    // Configure the navigation item.
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: titleView)

    updateGradientColors()
    updateHourlyTimer()
    recreateTableModel()

    nd.add(name: .lccAvailableItemsChanged) { [weak self] _ in self?.availableItemsChanged() }
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
    if updatingTableModel {
      return
    }
    updatingTableModel = true

    DispatchQueue.main.async {
      WatchHelper.sharedInstance.updatedData(client: self.services.localCachingClient)
      self.updatingTableModel = false
      self.recreateTableModel()
    }
  }

  private func recreateTableModel() {
    guard let user = services.localCachingClient.getUserInfo() else { return }

    // make sure that the selected subject level is reset each time table is loaded in case things
    // change
    selectedSubjectCatalogLevel = -1

    let lessons = services.localCachingClient.availableLessonCount
    let reviews = services.localCachingClient.availableReviewCount
    let recentMistakes = services.localCachingClient.getRecentMistakesCount()
    let recentLessonCount = services.localCachingClient.recentLessonCount
    let upcomingReviews = services.localCachingClient.upcomingReviews
    let currentLevelAssignments = services.localCachingClient.getAssignmentsAtUsersCurrentLevel()

    let model = MutableTableModel(tableView: tableView)

    if !user.hasVacationStartedAt {
      model.add(section: "Currently available")
      let lessonsItem = BasicModelItem(style: .value1,
                                       title: "Lessons",
                                       subtitle: "",
                                       accessoryType: .disclosureIndicator,
                                       target: self,
                                       action: #selector(startLessons))
      let apprenticeCount = services.localCachingClient.apprenticeCount
      let limit = Settings.apprenticeLessonsLimit
      let disabledMessage = apprenticeCount >= limit ? "apprentice limit reached" : nil
      hasLessons = setTableViewCellCount(lessonsItem, count: lessons,
                                         disabledMessage: disabledMessage)
      model.add(lessonsItem)

      let reviewsItem = BasicModelItem(style: .value1,
                                       title: "Reviews",
                                       subtitle: "",
                                       accessoryType: .disclosureIndicator,
                                       target: self,
                                       action: #selector(startReviews))
      hasReviews = setTableViewCellCount(reviewsItem, count: reviews)
      model.add(reviewsItem)

      model.add(section: "Upcoming reviews")
      model.add(UpcomingReviewsChartItem(upcomingReviews, currentReviewCount: reviews, at: Date(),
                                         target: self, action: #selector(showTableForecast)))
      model
        .add(createCurrentLevelReviewTimeItem(services: services,
                                              currentLevelAssignments: currentLevelAssignments))

      if recentLessonCount > 0 {
        let recentLessonsItem = BasicModelItem(style: .value1,
                                               title: "Review recent lessons",
                                               subtitle: "",
                                               accessoryType: .disclosureIndicator,
                                               target: self,
                                               action: #selector(startRecentLessonReviews))
        _ = setTableViewCellCount(recentLessonsItem, count: recentLessonCount)
        model.add(recentLessonsItem)
      }

      if recentMistakes > 0 {
        let recentMistakesItem = BasicModelItem(style: .value1,
                                                title: "Review recent mistakes",
                                                subtitle: "",
                                                accessoryType: .disclosureIndicator,
                                                target: self,
                                                action: #selector(startRecentMistakeReviews))
        _ = setTableViewCellCount(recentMistakesItem, count: recentMistakes)
        model.add(recentMistakesItem)
      }
    }

    if Settings.showPreviousLevelGraph, user.currentLevel > 1,
       !services.localCachingClient.hasCompletedPreviousLevel() {
      let previousLevel = Int(user.currentLevel) - 1
      model
        .add(section: "Current level (\(user.currentLevel - 1))")
      let currentGraphLevelAssignments = services.localCachingClient
        .getAssignments(level: previousLevel)
      model.add(CurrentLevelChartItem(currentLevelAssignments: currentGraphLevelAssignments))
      addShowRemainingAllItems(model: model, level: previousLevel)
      // add header for next section; graph and other items will be added after this if/else block
      model.add(section: "Next level (\(user.currentLevel))")
    } else {
      model.add(section: "Current level")
    }

    model.add(CurrentLevelChartItem(currentLevelAssignments: currentLevelAssignments))

    if !user.hasVacationStartedAt {
      model
        .add(createLevelTimeRemainingItem(services: services,
                                          currentLevelAssignments: currentLevelAssignments))
    }
    addShowRemainingAllItems(model: model, level: Int(user.currentLevel))

    model.add(section: "All levels")
    for category in SRSStageCategory.apprentice ... SRSStageCategory.burned {
      let count = services.localCachingClient.srsCategoryCounts[category.rawValue]
      model.add(SRSStageCategoryItem(stageCategory: category, count: Int(count)))
      if category == SRSStageCategory.burned, count > 0 {
        let reviewBurnedItem = BasicModelItem(style: .value1,
                                              title: "Review burned items",
                                              subtitle: "",
                                              accessoryType: .disclosureIndicator,
                                              target: self,
                                              action: #selector(startBurnedItemReviews))
        model.add(reviewBurnedItem)
      }
    }

    self.model = model
    tableView.reloadData()

    updateUserInfo()
  }

  private func addShowRemainingAllItems(model: MutableTableModel, level: Int) {
    model.add(BasicModelItem(style: .default,
                             title: "Show remaining",
                             subtitle: nil,
                             accessoryType: .disclosureIndicator) {
        self.selectedSubjectCatalogLevel = level
        self.performSegue(withIdentifier: "showRemaining", sender: self)
      })
    model.add(BasicModelItem(style: .default,
                             title: "Show all",
                             subtitle: "",
                             accessoryType: .disclosureIndicator) {
        self.selectedSubjectCatalogLevel = level
        self.performSegue(withIdentifier: "showAll", sender: self)
      })
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
    tableView.contentOffset = CGPoint(x: 0, y: -tableView.contentInset.top)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "startReviews":
      let assignments = services.localCachingClient.getAllAssignments()
      let items = ReviewItem.readyForReview(assignments: assignments,
                                            localCachingClient: services.localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items)

    case "startRecentMistakeReviews":
      let assignments = services.localCachingClient.getAllRecentMistakeAssignments()
      let items = ReviewItem.readyForRecentMistakesReview(assignments: assignments,
                                                          localCachingClient: services
                                                            .localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    case "startRecentLessonReviews":
      let assignments = services.localCachingClient.getAllRecentLessonAssignments()
      let items = ReviewItem.readyForRecentLessonReview(assignments: assignments,
                                                        localCachingClient: services
                                                          .localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    case "startBurnedItemReviews":
      let assignments = services.localCachingClient.getAllBurnedAssignments()
      let items = ReviewItem.readyForBurnedReview(assignments: assignments,
                                                  localCachingClient: services
                                                    .localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    case "startLessons":
      let assignments = services.localCachingClient.getAllAssignments()
      var items = ReviewItem.readyForLessons(assignments: assignments,
                                             localCachingClient: services.localCachingClient)
      if items.count == 0 {
        return
      }

      items = items.sorted(by: { a, b in a.compareForLessons(other: b) })
      if items.count > Settings.lessonBatchSize {
        items = Array(items[0 ..< Int(Settings.lessonBatchSize)])
      }

      let vc = segue.destination as! LessonsViewController
      vc.setup(services: services, items: items)

    case "showAll":
      let vc = segue.destination as! SubjectCatalogueViewController
      vc.setup(services: services, level: selectedSubjectCatalogLevel)

    case "showRemaining":
      let vc = segue.destination as! SubjectsRemainingViewController
      vc.setup(services: services, level: selectedSubjectCatalogLevel)

    case "settings":
      let vc = segue.destination as! SettingsViewController
      vc.setup(services: services)

    case "tableForecast":
      let vc = segue.destination as! UpcomingReviewsViewController
      vc.setup(services: services)

    default:
      break
    }
  }

  override func traitCollectionDidChange(_: UITraitCollection?) {
    updateGradientColors()
  }

  // MARK: - UITableViewDelegate

  func tableView(_: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.section == kUpcomingReviewsSection {
      return UIDevice.current.userInterfaceIdiom == .pad ? 360 : 120
    }
    return UITableView.automaticDimension
  }

  // MARK: - Navigation bar buttons

  @IBAction func searchButtonTapped() {
    present(searchController, animated: true, completion: nil)
  }

  @IBAction func settingsButtonTapped() {
    performSegue(withIdentifier: "settings", sender: self)
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
    let email = Settings.userEmailAddress
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

    var top: CGFloat = 20.0
    var vacationAlpha: CGFloat = 0.0
    if user.hasVacationStartedAt {
      top += vacationView.frame.height
      vacationAlpha = 1.0
    }

    let animations = {
      self.tableView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
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

    let vc = storyboard?.instantiateViewController(withIdentifier: "login") as! LoginViewController
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

  func didPullToRefresh() {
    tableView.refreshControl?.endRefreshing()
    refresh(quick: false)
  }

  // MARK: - Search

  func searchResultSelected(subject: TKMSubject) {
    let vc = storyboard?
      .instantiateViewController(withIdentifier: "subjectDetailsViewController") as! SubjectDetailsViewController
    vc.setup(services: services, subject: subject, showHints: true, hideBackButton: false, index: 0)
    searchController.dismiss(animated: true) {
      self.navigationController?.pushViewController(vc, animated: true)
    }
  }

  // MARK: - Keyboard navigation

  @objc func startReviews() {
    performSegue(withIdentifier: "startReviews", sender: self)
  }

  @objc func startRecentMistakeReviews() {
    performSegue(withIdentifier: "startRecentMistakeReviews", sender: self)
  }

  @objc func startRecentLessonReviews() {
    performSegue(withIdentifier: "startRecentLessonReviews", sender: self)
  }

  @objc func startBurnedItemReviews() {
    performSegue(withIdentifier: "startBurnedItemReviews", sender: self)
  }

  @objc func startLessons() {
    performSegue(withIdentifier: "startLessons", sender: self)
  }

  @objc func showTableForecast() {
    performSegue(withIdentifier: "tableForecast", sender: self)
  }

  override var keyCommands: [UIKeyCommand]? {
    var ret = [UIKeyCommand]()

    // Press return to keep studying, first lessons then reviews
    if hasLessons, !hasReviews {
      ret.append(UIKeyCommand(input: "\r",
                              modifierFlags: [],
                              action: #selector(startLessons),
                              discoverabilityTitle: "Continue lessons"))
    } else if hasReviews {
      ret.append(UIKeyCommand(input: "\r",
                              modifierFlags: [],
                              action: #selector(startReviews),
                              discoverabilityTitle: "Continue reviews"))
    }

    // Command L to start lessons, if any
    if hasLessons {
      ret.append(UIKeyCommand(input: "l",
                              modifierFlags: [.command],
                              action: #selector(startLessons),
                              discoverabilityTitle: "Start lessons"))
    }

    // Command R to start reviews, if any
    if hasReviews {
      ret.append(UIKeyCommand(input: "r",
                              modifierFlags: [.command],
                              action: #selector(startReviews),
                              discoverabilityTitle: "Start reviews"))
    }

    return ret
  }
}
