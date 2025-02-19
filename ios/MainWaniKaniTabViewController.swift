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
import WaniKaniAPI

private func setTableViewCellCount(_ item: BasicModelItem, count: Int,
                                   disabledMessage: String? = nil) -> Bool {
  item.subtitle = count < 0 ? "-" : "\(count)"
  item.isEnabled = count > 0 && (disabledMessage == nil)

  if let message = disabledMessage {
    item.title = "\(item.title!) (\(message))"
  }

  return item.isEnabled
}

class MainWaniKaniTabViewController: UITableViewController {
  protocol Delegate: AnyObject {
    func didPullToRefresh()
  }

  var services: TKMServices!
  var model: TableModel!
  weak var delegate: Delegate?

  var selectedSubjectCatalogLevel = -1
  var selectedSrsStageCategory = SRSStageCategory.apprentice

  var hasLessons = false
  var hasReviews = false

  func setup(services: TKMServices, delegate: Delegate?) {
    self.services = services
    self.delegate = delegate
  }

  override func viewDidLoad() {
    // Add a refresh control for when the user pulls down.
    let refreshControl = UIRefreshControl()
    refreshControl.tintColor = TKMStyle.Color.label
    refreshControl.backgroundColor = nil
    refreshControl.attributedTitle = NSMutableAttributedString(string: "Pull to refresh...")
    refreshControl.addAction(for: .valueChanged) { [unowned self, unowned refreshControl] in
      refreshControl.endRefreshing()
      self.delegate?.didPullToRefresh()
    }
    tableView.refreshControl = refreshControl

    recreateTableModel()
  }

  func update() {
    recreateTableModel()
  }

  private func recreateTableModel() {
    guard let user = services.localCachingClient.getUserInfo() else { return }

    // make sure that the selected subject level is reset each time table is loaded in case things
    // change
    selectedSubjectCatalogLevel = -1
    selectedSrsStageCategory = SRSStageCategory.apprentice

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
                                       accessoryType: .disclosureIndicator) { [unowned self] in self
        .startLessons()
      }
      let apprenticeCount = services.localCachingClient.apprenticeCount
      let limit = Settings.apprenticeLessonsLimit
      let disabledMessage = apprenticeCount >= limit ? "apprentice limit reached" : nil
      hasLessons = setTableViewCellCount(lessonsItem, count: lessons,
                                         disabledMessage: disabledMessage)
      model.add(lessonsItem)

      if lessons > 0 && apprenticeCount < limit {
        model.add(BasicModelItem(style: .value1,
                                 title: "Lesson Picker",
                                 subtitle: "",
                                 accessoryType: .disclosureIndicator) { [unowned self] in
            self.showLessonPicker()
          })
      }

      let reviewsItem = BasicModelItem(style: .value1,
                                       title: "Reviews",
                                       subtitle: "",
                                       accessoryType: .disclosureIndicator) { [unowned self] in self
        .startReviews()
      }
      hasReviews = setTableViewCellCount(reviewsItem, count: reviews)
      model.add(reviewsItem)

      model.add(section: "Upcoming reviews")
      model.add(UpcomingReviewsChartItem(upcomingReviews: upcomingReviews,
                                         currentReviewCount: reviews,
                                         date: Date()) { [unowned self] in self.showTableForecast()
        })
      model
        .add(createCurrentLevelReviewTimeItem(services: services,
                                              currentLevelAssignments: currentLevelAssignments))

      if recentLessonCount > 0 {
        let recentLessonsItem = BasicModelItem(style: .value1,
                                               title: "Review recent lessons",
                                               subtitle: "",
                                               accessoryType: .disclosureIndicator) { [
          unowned self
        ] in
          self.startRecentLessonReviews()
        }
        _ = setTableViewCellCount(recentLessonsItem, count: recentLessonCount)
        model.add(recentLessonsItem)
      }

      if recentMistakes > 0 {
        let recentMistakesItem = BasicModelItem(style: .value1,
                                                title: "Review recent mistakes",
                                                subtitle: "",
                                                accessoryType: .disclosureIndicator) { [
          unowned self
        ] in
          self.startRecentMistakeReviews()
        }
        _ = setTableViewCellCount(recentMistakesItem, count: recentMistakes)
        model.add(recentMistakesItem)
      }
    }

    if Settings.showPreviousLevelGraph, user.currentLevel > 1,
       !services.localCachingClient.hasCompletedPreviousLevel() {
      let previousLevel = Int(user.currentLevel) - 1
      model
        .add(section: "Previous level (\(user.currentLevel - 1))")
      let currentGraphLevelAssignments = services.localCachingClient
        .getAssignments(level: previousLevel)
      model.add(CurrentLevelChartItem(currentLevelAssignments: currentGraphLevelAssignments))
      addShowRemainingAllItems(model: model, level: previousLevel)
      // add header for next section; graph and other items will be added after this if/else block
      model.add(section: "Current level (\(user.currentLevel))")
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
      let item = SRSStageCategoryItem(stageCategory: category, count: Int(count),
                                      accessoryType: count > 0 ? .disclosureIndicator : .none)
      if count > 0 {
        item.tapHandler = { [weak self] in
          if let self = self {
            self.selectedSrsStageCategory = category
            self.perform(segue: StoryboardSegue.Main.viewItemsInSrsCategory, sender: self)
          }
        }
      }
      model.add(item)
      if category == SRSStageCategory.burned, count > 0 {
        model.add(BasicModelItem(style: .value1,
                                 title: "Review burned items",
                                 subtitle: "",
                                 accessoryType: .disclosureIndicator) { [unowned self] in
            self.startBurnedItemReviews()
          })
      }
    }

    self.model = model
    tableView.reloadData()
  }

  private func addShowRemainingAllItems(model: MutableTableModel, level: Int) {
    model.add(BasicModelItem(style: .default,
                             title: "Show remaining",
                             subtitle: nil,
                             accessoryType: .disclosureIndicator) { [weak self] in
        if let self = self {
          self.selectedSubjectCatalogLevel = level
          self.perform(segue: StoryboardSegue.Main.showRemaining, sender: self)
        }
      })
    model.add(BasicModelItem(style: .default,
                             title: "Show all",
                             subtitle: "",
                             accessoryType: .disclosureIndicator) { [weak self] in
        if let self = self {
          self.selectedSubjectCatalogLevel = level
          self.perform(segue: StoryboardSegue.Main.showAll, sender: self)
        }
      })
  }

  // MARK: - UIViewController

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.Main(segue) {
    case .startReviews:
      let assignments = services.localCachingClient.getAllAssignments()
      var items = ReviewItem.readyForReview(assignments: assignments,
                                            localCachingClient: services.localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items)

    case .startRecentMistakeReviews:
      let assignments = services.localCachingClient.getAllRecentMistakeAssignments()
      let items = ReviewItem.readyForRecentMistakesReview(assignments: assignments,
                                                          localCachingClient: services
                                                            .localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    case .startRecentLessonReviews:
      let assignments = services.localCachingClient.getAllRecentLessonAssignments()
      let items = ReviewItem.readyForRecentLessonReview(assignments: assignments,
                                                        localCachingClient: services
                                                          .localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    case .startBurnedItemReviews:
      let assignments = services.localCachingClient.getAllBurnedAssignments()
      let items = ReviewItem.readyForBurnedReview(assignments: assignments,
                                                  localCachingClient: services
                                                    .localCachingClient)
      if items.count == 0 {
        return
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    case .startLessons:
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

    case .showLessonPicker:
      let vc = segue.destination as! LessonPickerViewController
      vc.setup(services: services)

    case .showAll:
      let vc = segue.destination as! SubjectCatalogueViewController
      vc.setup(services: services, level: selectedSubjectCatalogLevel)

    case .showRemaining:
      let vc = segue.destination as! SubjectsRemainingViewController
      vc.setup(services: services, level: selectedSubjectCatalogLevel)

    case .tableForecast:
      let vc = segue.destination as! UpcomingReviewsViewController
      vc.setup(services: services)

    case .viewItemsInSrsCategory:
      let vc = segue.destination as! SubjectsByCategoryViewController
      vc.setup(services: services, category: selectedSrsStageCategory,
               showAnswers: Settings.subjectCatalogueViewShowAnswers)

    default:
      break
    }
  }

  // MARK: - Keyboard navigation

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

  @objc func startReviews() {
    perform(segue: StoryboardSegue.Main.startReviews, sender: self)
  }

  @objc func startLessons() {
    perform(segue: StoryboardSegue.Main.startLessons, sender: self)
  }

  @objc func showLessonPicker() {
    perform(segue: StoryboardSegue.Main.showLessonPicker, sender: self)
  }

  @objc func showTableForecast() {
    perform(segue: StoryboardSegue.Main.tableForecast, sender: self)
  }

  @objc func startRecentMistakeReviews() {
    perform(segue: StoryboardSegue.Main.startRecentMistakeReviews, sender: self)
  }

  @objc func startRecentLessonReviews() {
    perform(segue: StoryboardSegue.Main.startRecentLessonReviews, sender: self)
  }

  @objc func startBurnedItemReviews() {
    perform(segue: StoryboardSegue.Main.startBurnedItemReviews, sender: self)
  }
}
