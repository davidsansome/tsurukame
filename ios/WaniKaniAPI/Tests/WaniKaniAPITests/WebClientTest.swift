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

import Hippolyte
import WaniKaniAPI

import XCTest

class WebClientTest: XCTestCase {
  var client: WaniKaniWebClient!

  var loggedOutCsrfTokenResponseData: Data!
  var loggedInCsrfTokenResponseData: Data!

  var getLoginPage: StubRequest!
  var postLoginPage: StubRequest!
  var getDashboardPage: StubRequest!
  var getApiToken: StubRequest!
  var createApiTokenGet: StubRequest!
  var createApiToken: StubRequest!

  override func setUp() {
    client = WaniKaniWebClient()
    Hippolyte.shared.start()

    loggedOutCsrfTokenResponseData = """
      <meta name="csrf-token" content="blahblah"/>
    """.data(using: .utf8)
    loggedInCsrfTokenResponseData = """
      <meta name="csrf-token" content="foobar123"/>
    """.data(using: .utf8)

    getLoginPage = StubRequest(method: .GET, url: URL(string: "https://www.wanikani.com/login")!)
    getLoginPage.response.headers["Set-Cookie"] =
      "_wanikani_session=sessioncookie1; path=/; secure; HttpOnly"
    getLoginPage.response.body = loggedOutCsrfTokenResponseData

    postLoginPage = StubRequest(method: .POST, url: URL(string: "https://www.wanikani.com/login")!)
    postLoginPage.bodyMatcher =
      StringMatcher(string: "user%5Bemail%5D=foo%40example.com&user%5Bpassword%5D=bar&user%5Bremember_me%5D=0&" +
        "authenticity_token=blahblah")
    postLoginPage.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie1")
    postLoginPage.response.statusCode = 302
    postLoginPage.response.headers["Set-Cookie"] =
      "_wanikani_session=sessioncookie2; path=/; secure; HttpOnly"
    postLoginPage.response.headers["Location"] = "https://www.wanikani.com/dashboard"

    getDashboardPage = StubRequest(method: .GET,
                                   url: URL(string: "https://www.wanikani.com/dashboard")!)
    getDashboardPage.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie2")

    getApiToken = StubRequest(method: .GET,
                              url: URL(string: "https://www.wanikani.com/settings/personal_access_tokens")!)
    getApiToken.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie2")
    getApiToken.response.body = """
      <tr data-id="personal-access-token__00112233-4455-6677-8899-aabbccddeeff">
        <td class="personal-access-token-description">
                          Tsurukame
                        </td>
        <td class="personal-access-token-token">
            <code>00112233-4455-6677-8899-aabbccddeeff</code>
        </td>
    """.data(using: .utf8)

    createApiTokenGet = StubRequest(method: .GET, url:
      URL(string: "https://www.wanikani.com/settings/personal_access_tokens")!)
    createApiTokenGet.response.body = loggedInCsrfTokenResponseData

    createApiToken = StubRequest(method: .POST, url:
      URL(string: "https://www.wanikani.com/settings/personal_access_tokens")!)
    createApiToken.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie2")
    createApiToken
      .bodyMatcher = StringMatcher(string:
        "description=Tsurukame&" +
          "permissions%5Bassignments%5D%5Bstart%5D=0&" +
          "permissions%5Bassignments%5D%5Bstart%5D=1&" +
          "permissions%5Breviews%5D%5Bcreate%5D=0&" +
          "permissions%5Breviews%5D%5Bcreate%5D=1&" +
          "permissions%5Bstudy_materials%5D%5Bcreate%5D=0&" +
          "permissions%5Bstudy_materials%5D%5Bcreate%5D=1&" +
          "permissions%5Bstudy_materials%5D%5Bupdate%5D=0&" +
          "permissions%5Bstudy_materials%5D%5Bupdate%5D=1&" +
          "permissions%5Buser%5D%5Bupdate%5D=0&" +
          "authenticity_token=foobar123&" +
          "button=")
    createApiToken.response.body = """
      <tr data-id="personal-access-token__e03af9dd-aaa9-4a17-921e-3a29315767ec">
        <td class="personal-access-token-description">
                          Tsurukame
                        </td>
        <td class="personal-access-token-token">
            <code>e03af9dd-aaa9-4a17-921e-3a29315767ec</code>
        </td>
    """.data(using: .utf8)
  }

  override class func tearDown() {
    Hippolyte.shared.stop()
  }

  func testSuccessfulLogin() {
    Hippolyte.shared.add(stubbedRequest: getLoginPage)
    Hippolyte.shared.add(stubbedRequest: postLoginPage)
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)
    Hippolyte.shared.add(stubbedRequest: getApiToken)

    if let response = waitForPromise(client.login(email: "foo@example.com", password: "bar")) {
      XCTAssertEqual(response.cookie, "sessioncookie2")
      XCTAssertEqual(response.apiToken, "00112233-4455-6677-8899-aabbccddeeff")
    }
  }

  func testMissingCsrfToken() {
    getLoginPage.response.body = Data()
    Hippolyte.shared.add(stubbedRequest: getLoginPage)

    if let error = waitForError(client.login(email: "foo@example.com", password: "bar")) {
      guard let webClientError = error as? WaniKaniWebClientError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }
      XCTAssertEqual(webClientError, WaniKaniWebClientError.csrfTokenNotFound)
    }
  }

  func testMissingSessionCookie() {
    getLoginPage.response.headers.removeValue(forKey: "Set-Cookie")
    Hippolyte.shared.add(stubbedRequest: getLoginPage)

    if let error = waitForError(client.login(email: "foo@example.com", password: "bar")) {
      guard let webClientError = error as? WaniKaniWebClientError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }
      XCTAssertEqual(webClientError, WaniKaniWebClientError.sessionCookieNotSet)
    }
  }

  func testBadCredentials() {
    postLoginPage.response.headers.removeValue(forKey: "Set-Cookie")
    getDashboardPage.setHeader(key: "Cookie", value: "_wanikani_session=sessioncookie1")
    Hippolyte.shared.add(stubbedRequest: getLoginPage)
    Hippolyte.shared.add(stubbedRequest: postLoginPage)
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)

    if let error = waitForError(client.login(email: "foo@example.com", password: "bar")) {
      guard let webClientError = error as? WaniKaniWebClientError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }
      XCTAssertEqual(webClientError, WaniKaniWebClientError.badCredentials)
    }
  }

  func testCreateNewApiToken() {
    getApiToken.response.body = loggedInCsrfTokenResponseData
    Hippolyte.shared.add(stubbedRequest: getLoginPage)
    Hippolyte.shared.add(stubbedRequest: postLoginPage)
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)
    Hippolyte.shared.add(stubbedRequest: getApiToken)
    Hippolyte.shared.add(stubbedRequest: createApiTokenGet)
    Hippolyte.shared.add(stubbedRequest: createApiToken)

    if let response = waitForPromise(client.login(email: "foo@example.com", password: "bar")) {
      XCTAssertEqual(response.cookie, "sessioncookie2")
      XCTAssertEqual(response.apiToken, "e03af9dd-aaa9-4a17-921e-3a29315767ec")
    }
  }

  func testCreateNewApiTokenFailed() {
    getApiToken.response.body = loggedInCsrfTokenResponseData
    createApiToken.response.body = loggedInCsrfTokenResponseData
    Hippolyte.shared.add(stubbedRequest: getLoginPage)
    Hippolyte.shared.add(stubbedRequest: postLoginPage)
    Hippolyte.shared.add(stubbedRequest: getDashboardPage)
    Hippolyte.shared.add(stubbedRequest: getApiToken)
    Hippolyte.shared.add(stubbedRequest: createApiTokenGet)
    Hippolyte.shared.add(stubbedRequest: createApiToken)

    if let error = waitForError(client.login(email: "foo@example.com", password: "bar")) {
      guard let webClientError = error as? WaniKaniWebClientError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }
      XCTAssertEqual(webClientError, WaniKaniWebClientError.apiTokenNotFound)
    }
  }
}
