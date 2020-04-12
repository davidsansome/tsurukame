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

private let kDefaultProfileImageURL =
  "https://cdn.wanikani.com/default-avatar-300x300-20121121.png"
private let kProfileImageSize: CGFloat = 80

private let kUpcomingReviewsSection = 1

private func userProfileImageURL(emailAddress: String) -> URL {
  let address = emailAddress.trimmingCharacters(in: .whitespaces)
    .lowercased()
  let hash = address.MD5()

  let size = kProfileImageSize * UIScreen.main.scale

  return URL(string: "https://www.gravatar.com/avatar/\(hash).jpg?s=\(size)&d=\(kDefaultProfileImageURL)")!
}

private func setTableViewCellCount(_ item: TKMBasicModelItem, count: Int) -> Bool {
  item.subtitle = count < 0 ? "-" : "\(count)"
  item.enabled = count > 0
  return item.enabled
}

@objc
class MainViewController: UITableViewController, LoginViewControllerDelegate,
  MainHeaderViewDelegate,
  SearchResultViewControllerDelegate, UISearchControllerDelegate {
  var services: TKMServices!
  var model: TKMTableModel!
  @IBOutlet var headerView: MainHeaderView!
  var searchController: UISearchController!
  weak var searchResultsViewController: SearchResultViewController!
  var hourlyRefreshTimer = Timer()
  var isShowingUnauthorizedAlert = false
  var hasLessons = false
  var hasReviews = false
  var updatingTableModel = false

  @objc
  func setup(services: TKMServices) {
    self.services = services
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    headerView.delegate = self

    // Show a background image.
    let backgroundView = UIImageView(image: UIImage(named: "launch_screen"))
    backgroundView.alpha = 0.25
    tableView.backgroundView = backgroundView

    // Add a refresh control for when the user pulls down.
    refreshControl = UIRefreshControl()
    refreshControl?.tintColor = .white
    refreshControl?.backgroundColor = nil
    refreshControl?.attributedTitle = NSMutableAttributedString(string: "Pull to refresh...",
                                                                attributes: [.foregroundColor: UIColor
                                                                  .white])
    refreshControl?.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

    // Create the search results view controller.
    let searchResultsVC = storyboard?
      .instantiateViewController(withIdentifier: "searchResults") as! SearchResultViewController
    searchResultsVC.setup(with: services, delegate: self)
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

    updateHourlyTimer()
    recreateTableModel()

    let nc = NotificationCenter.default
    nc.addObserver(self,
                   selector: #selector(availableItemsChanged),
                   name: NSNotification.Name.localCachingClientAvailableItemsChanged,
                   object: services.localCachingClient)
    nc.addObserver(self,
                   selector: #selector(userInfoChanged),
                   name: NSNotification.Name.localCachingClientUserInfoChanged,
                   object: services.localCachingClient)
    nc.addObserver(self,
                   selector: #selector(srsLevelCountsChanged),
                   name: NSNotification.Name.localCachingClientSrsLevelCountsChanged,
                   object: services.localCachingClient)
    nc.addObserver(self,
                   selector: #selector(clientIsUnauthorized),
                   name: NSNotification.Name.localCachingClientUnauthorized,
                   object: services.localCachingClient)
    nc.addObserver(self,
                   selector: #selector(applicationDidEnterBackground),
                   name: UIApplication.didEnterBackgroundNotification,
                   object: nil)
    nc.addObserver(self,
                   selector: #selector(applicationWillEnterForeground),
                   name: UIApplication.willEnterForegroundNotification,
                   object: nil)
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

    let lessons = Int(services.localCachingClient.availableLessonCount)
    let reviews = Int(services.localCachingClient.availableReviewCount)
    let upcomingReviews = services.localCachingClient.upcomingReviews as! [Int]
    let currentLevelAssignments = services.localCachingClient.getAssignmentsAtUsersCurrentLevel()

    let model = TKMMutableTableModel(tableView: tableView)

    if !user.hasVacationStartedAt {
      model.addSection("Currently available")
      let lessonsItem = TKMBasicModelItem(style: .value1,
                                          title: "Lessons",
                                          subtitle: "",
                                          accessoryType: .disclosureIndicator,
                                          target: self,
                                          action: #selector(startLessons))
      hasLessons = setTableViewCellCount(lessonsItem, count: lessons)
      model.add(lessonsItem)

      let reviewsItem = TKMBasicModelItem(style: .value1,
                                          title: "Reviews",
                                          subtitle: "",
                                          accessoryType: .disclosureIndicator,
                                          target: self,
                                          action: #selector(startReviews))
      hasReviews = setTableViewCellCount(reviewsItem, count: reviews)
      model.add(reviewsItem)

      model.addSection("Upcoming reviews")
      model.add(UpcomingReviewsChartItem(upcomingReviews, currentReviewCount: reviews, at: Date()))
      model
        .add(createCurrentLevelReviewTimeItem(services: services,
                                              currentLevelAssignments: currentLevelAssignments))
    }

    model.addSection("This level")
    model.add(CurrentLevelChartItem(dataLoader: services.dataLoader,
                                    currentLevelAssignments: currentLevelAssignments))

    if !user.hasVacationStartedAt {
      model
        .add(createLevelTimeRemainingItem(services: services,
                                          currentLevelAssignments: currentLevelAssignments))
    }
    model.add(TKMBasicModelItem(style: .default,
                                title: "Show remaining",
                                subtitle: nil,
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(showRemaining)))
    model.add(TKMBasicModelItem(style: .default,
                                title: "Show all",
                                subtitle: "",
                                accessoryType: .disclosureIndicator,
                                target: self,
                                action: #selector(showAll)))

    model.addSection("All levels")
    for i in TKMSRSStageCategory.apprentice.rawValue ... TKMSRSStageCategory.burned.rawValue {
      let category = TKMSRSStageCategory(rawValue: i)!
      let count = services.localCachingClient.getSrsLevelCount(category)
      model.add(SRSStageCategoryItem(stageCategory: category, count: Int(count)))
    }

    self.model = model
    tableView.reloadData()
  }

  // MARK: - UIViewController

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cancelHourlyTimer()
  }

  override func viewWillAppear(_ animated: Bool) {
    refresh(quick: true)
    updateHourlyTimer()

    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()

    // Bring the refresh control above the gradient.
    refreshControl?.superview?.bringSubviewToFront(refreshControl!)

    let headerSize = headerView.sizeThatFits(CGSize(width: view.bounds.size.width, height: 0))
    headerView.frame = CGRect(origin: headerView.frame.origin, size: headerSize)
  }

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch segue.identifier {
    case "startReviews":
      let assignments = services.localCachingClient.getAllAssignments()
      let items = ReviewItem.assignmentsReady(forReview: assignments,
                                              dataLoader: services.dataLoader,
                                              localCachingClient: services.localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! TKMReviewContainerViewController
      vc.setup(with: services, items: items)

    case "startLessons":
      let assignments = services.localCachingClient.getAllAssignments()
      var items = ReviewItem.assignmentsReady(forLesson: assignments,
                                              dataLoader: services.dataLoader,
                                              localCachingClient: services.localCachingClient)
      if items.count == 0 {
        return
      }

      items = items.sorted(by: { a, b in a.compare(forLessons: b) })
      if items.count > Settings.lessonBatchSize {
        items = Array(items[0 ..< Int(Settings.lessonBatchSize)])
      }

      let vc = segue.destination as! LessonsViewController
      vc.setup(with: services, items: items)

    case "showAll":
      let vc = segue.destination as! SubjectCatalogueViewController
      let level = services.localCachingClient.getUserInfo()!.level
      vc.setup(with: services, level: level)

    case "showRemaining":
      let vc = segue.destination as! SubjectsRemainingViewController
      vc.setup(with: services)

    case "settings":
      let vc = segue.destination as! SettingsViewController
      vc.setup(with: services)

    default:
      break
    }
  }

  // MARK: - UITableViewController

  override func tableView(_ tableView: UITableView,
                          heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.section == kUpcomingReviewsSection {
      return UIDevice.current.userInterfaceIdiom == .pad ? 360 : 120
    }

    return super.tableView(tableView, heightForRowAt: indexPath)
  }

  // MARK: - MainHeaderViewDelegate

  func searchButtonTapped() {
    present(searchController, animated: true, completion: nil)
  }

  func settingsButtonTapped() {
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
    refresh(quick: true)
    updateHourlyTimer()
  }

  @objc
  func applicationDidEnterBackground() {
    cancelHourlyTimer()
  }

  @objc
  func applicationWillEnterForeground() {
    updateHourlyTimer()
  }

  // MARK: - Refreshing contents

  @objc(refreshQuick:)
  func refresh(quick: Bool) {
    updateUserInfo()
    scheduleTableModelUpdate()
    guard let headerView = headerView else { return }
    headerView.setProgress(0)
    services.localCachingClient.sync(progressHandler: { progress in
      self.headerView.setProgress(progress)
    }, quick: quick)
  }

  @objc func availableItemsChanged() {
    if (view?.window) != nil {
      scheduleTableModelUpdate()
    }
  }

  @objc func userInfoChanged() {
    updateUserInfo()
  }

  func updateUserInfo() {
    guard let user = services.localCachingClient.getUserInfo(),
      let email = Settings.userEmailAddress,
      let headerView = headerView else {
      return
    }
    let guruKanji = services.localCachingClient.getGuruKanjiCount()
    let imageURL = email.isEmpty ? URL(string: kDefaultProfileImageURL)
      : userProfileImageURL(emailAddress: email)

    headerView.update(username: user.username,
                      level: Int(user.level),
                      guruKanji: Int(guruKanji),
                      imageURL: imageURL,
                      vacationMode: user.hasVacationStartedAt)
    headerView.layoutIfNeeded()

    // Make the header view as short as possible.
    let height = headerView.sizeThatFits(CGSize(width: view.bounds.size.width, height: 0)).height
    var frame = headerView.frame
    frame.size.height = height
    headerView.frame = frame
  }

  @objc func srsLevelCountsChanged() {
    if (view?.window) != nil {
      updateUserInfo()
      scheduleTableModelUpdate()
    }
  }

  @objc func clientIsUnauthorized() {
    if isShowingUnauthorizedAlert {
      return
    }
    isShowingUnauthorizedAlert = true

    let ac = UIAlertController(title: "Logged out",
                               message: "Your API Token expired - please log in again. You won't lose your review progress",
                               preferredStyle: .alert)

    ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
      self.loginAgain()
    }))
    present(ac, animated: true, completion: nil)
  }

  func loginAgain() {
    guard let user = services.localCachingClient.getUserInfo() else {
      return
    }

    let vc = storyboard?.instantiateViewController(withIdentifier: "login") as! LoginViewController
    vc.delegate = self
    vc.forcedUsername = user.username
    navigationController?.pushViewController(vc, animated: true)
  }

  func loginComplete() {
    services.localCachingClient.client
      .updateApiToken(Settings.userApiToken, cookie: Settings.userCookie)
    navigationController?.popViewController(animated: true)
    isShowingUnauthorizedAlert = false
  }

  @objc func didPullToRefresh() {
    refreshControl?.endRefreshing()
    refresh(quick: false)
  }

  // MARK: - Search

  func searchResultSelected(_ subject: TKMSubject) {
    let vc = storyboard?
      .instantiateViewController(withIdentifier: "subjectDetailsViewController") as! SubjectDetailsViewController
    vc.setup(with: services, subject: subject, showHints: true, hideBackButton: false, index: 0)
    searchController.dismiss(animated: true) {
      self.navigationController?.pushViewController(vc, animated: true)
    }
  }

  // MARK: - Keyboard navigation

  @objc func startReviews() {
    performSegue(withIdentifier: "startReviews", sender: self)
  }

  @objc func startLessons() {
    performSegue(withIdentifier: "startLessons", sender: self)
  }

  @objc func showRemaining() {
    performSegue(withIdentifier: "showRemaining", sender: self)
  }

  @objc func showAll() {
    performSegue(withIdentifier: "showAll", sender: self)
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
