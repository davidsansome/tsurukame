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
import PromiseKit

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
        if ProcessInfo.processInfo.arguments.contains("ResetUserDefaults") {
          // We're run again after testing finishes to remove the dummy user.
          Settings.userCookie = ""
          Settings.userApiToken = ""
          Settings.userEmailAddress = ""
        } else {
          // Pretend there's a logged in user.
          Settings.userCookie = "dummy"
          Settings.userApiToken = "dummy"
          Settings.userEmailAddress = "dummy"
          Settings.showSRSLevelIndicator = true
        }
      }
    }

    static let localCachingClientClass =
      isActive ? FakeLocalCachingClient.self : LocalCachingClient.self
  }

  class FakeLocalCachingClient: LocalCachingClient {
    override func countRows(inTable _: String) -> Int {
      0
    }

    override func updateAvailableSubjects() -> (Int, Int, [Int]) {
      return (10, 4, [14, 8, 2, 1, 12, 42, 17, 9, 2, 0, 2, 17, 0, 0, 6, 0, 0, 0, 0, 4, 11, 0, 8,
                      6])
    }

    override func updateGuruKanjiCount() -> Int {
      864
    }

    override func updateSrsCategoryCounts() -> [Int] {
      [86, 120, 485, 786, 2056]
    }

    override func getAllAssignments() -> [TKMAssignment] {
      // Return some assignments for a review.
      let a = TKMAssignment()
      a.subjectId = 511
      a.subjectType = .kanji
      a.availableAt = 42
      a.srsStage = 2
      return Array(repeating: a, count: Int(availableSubjects.reviewCount))
    }

    override func getStudyMaterial(subjectId _: Int) -> TKMStudyMaterials? {
      nil
    }

    override func getUserInfo() -> TKMUser? {
      let user = TKMUser()
      user.level = 24
      user.username = "Fred"
      user.maxLevelGrantedBySubscription = 60
      return user
    }

    override func getAllPendingProgress() -> [TKMProgress] {
      []
    }

    override func getAssignment(subjectId _: Int) -> TKMAssignment? {
      nil
    }

    override func getAssignments(level: Int) -> [TKMAssignment] {
      // Return just enough to populate the SubjectsByLevelViewController.
      let level = getUserInfo()!.level
      let subjects = [TKMSubject]() // TODO: show some fake subjects.

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

    override func getAssignmentsAtUsersCurrentLevel() -> [TKMAssignment] {
      makePieSlices(.radical, locked: 0, lesson: 2, apprentice: 4, guru: 1) +
        makePieSlices(.kanji, locked: 8, lesson: 4, apprentice: 12, guru: 1) +
        makePieSlices(.vocabulary, locked: 50, lesson: 8, apprentice: 4, guru: 0)
    }

    override func sendProgress(_: [TKMProgress]) -> Promise<Void> {
      Promise.value(())
    }

    override func updateStudyMaterial(_: TKMStudyMaterials) -> Promise<Void> {
      Promise.value(())
    }

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

    private func makePieSlices(_ type: TKMSubject_Type,
                               locked: Int,
                               lesson: Int,
                               apprentice: Int,
                               guru: Int) -> [TKMAssignment] {
      Array(repeating: makeAssignment(type, srsStage: -1), count: locked) +
        Array(repeating: makeAssignment(type, srsStage: 0), count: lesson) +
        Array(repeating: makeAssignment(type, srsStage: 1), count: apprentice) +
        Array(repeating: makeAssignment(type, srsStage: 6), count: guru)
    }
  }

#endif
