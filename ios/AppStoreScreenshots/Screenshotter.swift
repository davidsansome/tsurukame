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

#if !DEBUG

  // In release mode this class does nothing.
  @objc(TKMScreenshotter)
  @objcMembers
  class Screenshotter: NSObject {
    static let isActive = false
    class func setUp() {}
    static let localCachingClientClass = LocalCachingClient.self
  }

#else

  // In debug mode this class detects whether the app is being run under "fastlane snapshot", and
  // if so will provide a LocalCachingClient that returns fake data for taking screenshots for the
  // app store.
  @objc(TKMScreenshotter)
  @objcMembers
  class Screenshotter: NSObject {
    static let isActive: Bool = {
      UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")
    }()

    class func setUp() {
      if isActive {
        // Pretend there's a logged in user.
        Settings.userCookie = "dummy"
        Settings.userApiToken = "dummy"
        Settings.showSRSLevelIndicator = true
      }
    }

    static let localCachingClientClass = {
      isActive ? FakeLocalCachingClient.self : LocalCachingClient.self
    }
  }

  @objc
  class FakeLocalCachingClient: LocalCachingClient {
    override var availableReviewCount: Int32 { 4 }
    override var availableLessonCount: Int32 { 10 }
    override var upcomingReviews: [NSNumber] {
      [14, 8, 2, 1, 12, 42, 17, 9, 2, 0, 2, 17, 0, 0, 6, 0, 0, 0, 0, 4, 11, 0, 8, 6]
    }

    override var pendingProgress: Int32 { 0 }
    override var pendingStudyMaterials: Int32 { 0 }

    override func sync(progressHandler syncProgressHandler: @escaping SyncProgressHandler, quick _: Bool) {
      syncProgressHandler(1.0)
    }

    override func getAllAssignments() -> [TKMAssignment] {
      // Return some assignments for a review.
      let a = TKMAssignment()
      a.subjectId = 511
      a.availableAt = 42
      a.srsStage = 2
      return Array(repeating: a, count: Int(availableReviewCount))
    }

    override func getStudyMaterial(forID _: Int32) -> TKMStudyMaterials? {
      return nil
    }

    override func getUserInfo() -> TKMUser? {
      let user = TKMUser()
      user.level = 24
      user.username = "Fred"
      user.maxLevelGrantedBySubscription = 60
      // TODO: add a profile photo.
      return user
    }

    override func getAllPendingProgress() -> [TKMProgress] {
      return []
    }

    override func getAssignmentForID(_: Int32) -> TKMAssignment? {
      return nil
    }

    override func getAssignmentsAtLevel(_: Int32) -> [TKMAssignment]? {
      // Return just enough to populate the SubjectsByLevelViewController.
      let level = getUserInfo()!.level
      let subjects = dataLoader.loadAll().filter { (s) -> Bool in
        s.level == level && s.subjectType != .vocabulary
      }

      srand48(42)

      var ret = [TKMAssignment]()
      for s in subjects {
        let a = TKMAssignment()
        a.subjectId = s.id_p
        a.subjectType = s.subjectType

        if a.subjectType == .radical {
          a.srsStage = 5
        } else {
          a.srsStage = Int32(drand48() * 6)
        }
        ret.append(a)
      }
      return ret
    }

    override func getAssignmentsAtUsersCurrentLevel() -> [TKMAssignment]? {
      return makePieSlices(.radical, locked: 0, lesson: 2, apprentice: 4, guru: 1) +
        makePieSlices(.kanji, locked: 8, lesson: 4, apprentice: 12, guru: 1) +
        makePieSlices(.vocabulary, locked: 50, lesson: 8, apprentice: 4, guru: 0)
    }

    override func getSrsLevelCount(_ category: TKMSRSStageCategory) -> Int32 {
      switch category {
      case .apprentice: return 86
      case .guru: return 120
      case .master: return 485
      case .enlightened: return 786
      case .burned: return 2056
      @unknown default:
        fatalError()
      }
    }

    override func getGuruKanjiCount() -> Int32 {
      return 864
    }

    override func getAverageRemainingLevelTime() -> TimeInterval {
      return (4 * 24 + 9) * 60 * 60
    }

    override func sendProgress(_: [TKMProgress]) {}

    override func updateStudyMaterial(_: TKMStudyMaterials) {}

    override func clearAllData() {}

    override func clearAllDataAndClose() {}

    private func makeAssignment(_ type: TKMSubject_Type, srsStage: Int32) -> TKMAssignment {
      let ret = TKMAssignment()
      ret.subjectType = type
      if srsStage != -1 {
        ret.srsStage = srsStage
      }
      return ret
    }

    private func makePieSlices(_ type: TKMSubject_Type, locked: Int, lesson: Int, apprentice: Int, guru: Int) -> [TKMAssignment] {
      return Array(repeating: makeAssignment(type, srsStage: -1), count: locked) +
        Array(repeating: makeAssignment(type, srsStage: 0), count: lesson) +
        Array(repeating: makeAssignment(type, srsStage: 1), count: apprentice) +
        Array(repeating: makeAssignment(type, srsStage: 6), count: guru)
    }
  }

#endif
