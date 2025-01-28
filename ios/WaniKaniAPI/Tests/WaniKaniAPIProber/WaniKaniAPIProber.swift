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
import XCTest

class WaniKaniAPIProber: XCTestCase {
  let semaphore = DispatchSemaphore(value: 0)

  let email = ProcessInfo.processInfo.environment["TSURUKAME_PROBER_EMAIL"]
  let password = ProcessInfo.processInfo.environment["TSURUKAME_PROBER_PASSWORD"]
  let environmentVariablesNotSetError =
    XCTSkip("TSURUKAME_PROBER_EMAIL and TSURUKAME_PROBER_PASSWORD environment variables must be set")

  let client = WaniKaniWebClient()

  override func setUp() {
    // Tell PromiseKit to execute callbacks on the global queue.
    let queue = DispatchQueue.global()
    PromiseKit.conf.Q.map = queue
    PromiseKit.conf.Q.return = queue
  }

  private func runAsync<T>(fn: () -> Promise<T>) throws -> T {
    var ret: T?
    var error: Error?

    firstly {
      fn()
    }.done {
      ret = $0
    }.catch {
      error = $0
    }.finally {
      self.semaphore.signal()
    }

    semaphore.wait()
    if let error = error {
      throw error
    }
    return ret!
  }

  func testWebLoginSuccessful() throws {
    guard let email = email, let password = password else {
      throw environmentVariablesNotSetError
    }

    let result = try runAsync {
      client.login(email: email, password: password)
    }

    XCTAssertFalse(result.apiToken.isEmpty)
    XCTAssertFalse(result.cookie.isEmpty)
  }

  func testGetUserInfo() throws {
    guard let email = email, let password = password else {
      throw environmentVariablesNotSetError
    }

    let result = try runAsync {
      firstly {
        client.login(email: email, password: password)
      }.then { (result: LoginResult) in
        let apiClient = WaniKaniAPIClient(apiToken: result.apiToken)
        return apiClient.user(progress: Progress())
      }
    }

    XCTAssertEqual(result.username, "tsurukame-prober")
    XCTAssertEqual(result.level, 1)
    XCTAssertEqual(result.maxLevelGrantedBySubscription, 3)
    XCTAssertFalse(result.subscribed)
  }

  func testGetSubjects() throws {
    guard let email = email, let password = password else {
      throw environmentVariablesNotSetError
    }

    let result = try runAsync {
      firstly {
        client.login(email: email, password: password)
      }.then { (result: LoginResult) in
        let apiClient = WaniKaniAPIClient(apiToken: result.apiToken)
        return apiClient.subjects(progress: Progress())
      }
    }

    // There were 9233 subjects on 2024-12-13.
    XCTAssertGreaterThan(result.subjects.count, 9000)

    var subjectsById = [Int64: TKMSubject]()
    for subject in result.subjects {
      subjectsById[subject.id] = subject
    }

    let big = subjectsById[18]!
    XCTAssertEqual(big.japanese, "大")
    XCTAssertTrue(big.hasRadical)
    XCTAssertEqual(big.meanings[0].meaning, "Big")
    XCTAssertEqual(big.level, 1)
  }
}
