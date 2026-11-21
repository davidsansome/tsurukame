// Copyright David Sansome
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

import Hippolyte
import WaniKaniAPI

import XCTest

class WebClientResurrectTest: XCTestCase {
  var client: WaniKaniWebClient!

  var getDashboardPage: StubRequest!
  var putResurrect: StubRequest!

  override func setUp() {
    client = WaniKaniWebClient()
    Hippolyte.shared.start()
    // Stubs from an earlier test stay registered and can answer this test's requests.
    Hippolyte.shared.clearStubs()

    getDashboardPage = StubRequest(method: .GET,
                                   url: URL(string: "https://www.wanikani.com/dashboard")!)
    getDashboardPage.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie")
    getDashboardPage.response.body = """
      <meta name="csrf-token" content="foobar123"/>
    """.data(using: .utf8)

    putResurrect = StubRequest(method: .PUT,
                               url: URL(string: "https://www.wanikani.com/assignments/440/resurrect")!)
    putResurrect.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie")
    putResurrect.setHeader(key: "X-CSRF-Token", value: "foobar123")
    putResurrect.response.statusCode = 302
    putResurrect.response.headers["Location"] = "https://www.wanikani.com/kanji/440"
  }

  override class func tearDown() {
    Hippolyte.shared.stop()
  }

  func testResurrect() {
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)
    Hippolyte.shared.add(stubbedRequest: putResurrect)

    XCTAssertNotNil(waitForPromise(client.resurrectSubject(subjectId: 440,
                                                           cookie: "sessioncookie")))
  }

  func testSessionExpired() {
    getDashboardPage.response.statusCode = 302
    getDashboardPage.response.headers["Location"] = "https://www.wanikani.com/login"
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)

    let error = waitForError(client.resurrectSubject(subjectId: 440, cookie: "sessioncookie"))
    XCTAssertEqual(error as? WaniKaniWebClientError, WaniKaniWebClientError.sessionExpired)
  }

  func testSessionExpiredOnResurrect() {
    putResurrect.response.headers["Location"] = "https://www.wanikani.com/login"
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)
    Hippolyte.shared.add(stubbedRequest: putResurrect)

    let error = waitForError(client.resurrectSubject(subjectId: 440, cookie: "sessioncookie"))
    XCTAssertEqual(error as? WaniKaniWebClientError, WaniKaniWebClientError.sessionExpired)
  }

  func testResurrectRejected() {
    putResurrect.response.statusCode = 422
    putResurrect.response.headers.removeValue(forKey: "Location")
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)
    Hippolyte.shared.add(stubbedRequest: putResurrect)

    let error = waitForError(client.resurrectSubject(subjectId: 440, cookie: "sessioncookie"))
    XCTAssertEqual(error as? WaniKaniWebClientError, WaniKaniWebClientError.resurrectFailed)
  }
}
