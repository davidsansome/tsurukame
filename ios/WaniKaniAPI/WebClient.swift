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

@objc
enum WaniKaniWebClientError: Int, Error {
  case csrfTokenNotFound
  case apiTokenNotFound
  case emailNotFound
  case sessionCookieNotSet
  case badCredentials
  case unknown

  var localizedDescription: String {
    switch self {
    case .csrfTokenNotFound:
      return "CSRF token not found"
    case .apiTokenNotFound:
      return "API token not found"
    case .emailNotFound:
      return "Email address not found"
    case .sessionCookieNotSet:
      return "Session cookie not set"
    case .badCredentials:
      return "Incorrect username or password"
    default:
      return "Unknown error"
    }
  }
}

// TODO: Convert this to a struct when we only call it from Swift.
@objc
@objcMembers
class LoginResult: NSObject {
  var cookie: String!
  var apiToken: String!
  var emailAddress: String!

  init(cookie: String, apiToken: String, emailAddress: String) {
    self.cookie = cookie
    self.apiToken = apiToken
    self.emailAddress = emailAddress
  }
}

@objc
class WaniKaniWebClient: NSObject {
  // MARK: - Login

  /**
   * Login to WaniKani using the username and password, then fetch the user's
   * API token (creating a new one if it didn't exist) and email address.
   */
  func login(username: String, password: String) -> Promise<LoginResult> {
    let cookie = getCookie(username: username, password: password)
    let token = cookie.then { cookie in
      self.getApiToken(cookie: cookie)
    }
    let email = cookie.then { cookie in
      self.getEmailAddress(cookie: cookie)
    }

    return when(fulfilled: [cookie, token, email]).map { arg in
      LoginResult(cookie: arg[0], apiToken: arg[1], emailAddress: arg[2])
    }
  }

  private func getCookie(username: String, password: String) -> Promise<String> {
    let session = URLSession(configuration: .ephemeral)
    var firstCookie: String?
    var secondCookie: String?

    return firstly { () -> DataTaskPromise in
      // Make a request to the login page to get the CSRF token.
      var req = URLRequest(url: kLoginUrl)
      req.httpShouldHandleCookies = true
      return request(req, session: session)
    }.then { (arg) -> DataTaskPromise in
      // Extract the CSRF token and session cookie from the response.

      let csrfToken = try self.extractCSRFToken(arg.data)
      firstCookie = try self.getSessionCookie(session)

      // Build the login request.
      let queryItems = [
        URLQueryItem(name: "user[login]", value: username),
        URLQueryItem(name: "user[password]", value: password),
        URLQueryItem(name: "user[remember_me]", value: "0"),
        URLQueryItem(name: "authenticity_token", value: csrfToken),
        URLQueryItem(name: "utf8", value: "✓"),
      ]

      var req = URLRequest(url: kLoginUrl)
      req.httpShouldHandleCookies = true
      try req.setFormBody(method: "POST", queryItems: queryItems)
      return request(req, session: session)
    }.map {
      secondCookie = try self.getSessionCookie(session)
      if firstCookie == secondCookie {
        throw WaniKaniWebClientError.badCredentials
      }
      if $0.response.url! != kDashboardUrl {
        throw WaniKaniWebClientError.unknown
      }
      return secondCookie!
    }
  }

  private func getApiToken(cookie: String) -> Promise<String> {
    firstly { () -> DataTaskPromise in
      let req = authorize(kAccessTokenUrl, cookie: cookie)
      return request(req, session: URLSession.shared)
    }.then { (arg) -> Promise<String> in
      if let apiToken = self.extractApiToken(arg.data) {
        return Promise.value(apiToken)
      }

      // No API token was found - we need to create one.
      return self.createApiToken(cookie: cookie)
    }
  }

  private func createApiToken(cookie: String) -> Promise<String> {
    firstly { () -> DataTaskPromise in
      let req = authorize(kNewAccessTokenUrl, cookie: cookie)
      return request(req)
    }.then { (arg) -> DataTaskPromise in
      let csrfToken = try self.extractCSRFToken(arg.data)

      let queryItems = [
        URLQueryItem(name: "personal_access_token[description]", value: "Tsurukame"),
        URLQueryItem(name: "personal_access_token[permissions][assignments][start]", value: "1"),
        URLQueryItem(name: "personal_access_token[permissions][reviews][create]", value: "1"),
        URLQueryItem(name: "personal_access_token[permissions][reviews][update]", value: "1"),
        URLQueryItem(name: "personal_access_token[permissions][study_materials][create]",
                     value: "1"),
        URLQueryItem(name: "personal_access_token[permissions][study_materials][update]",
                     value: "1"),
        URLQueryItem(name: "authenticity_token", value: csrfToken),
        URLQueryItem(name: "utf8", value: "✓"),
      ]

      var req = self.authorize(kNewAccessTokenUrl, cookie: cookie)
      try req.setFormBody(method: "POST", queryItems: queryItems)
      return request(req)
    }.map { (arg) throws -> String in
      if let apiToken = self.extractApiToken(arg.data) {
        return apiToken
      }
      throw WaniKaniWebClientError.apiTokenNotFound
    }
  }

  private func getEmailAddress(cookie: String) -> Promise<String> {
    firstly { () -> DataTaskPromise in
      let req = authorize(kAccountUrl, cookie: cookie)
      return request(req, session: URLSession.shared)
    }.map { (arg) -> String in
      try self.extractEmail(arg.data)
    }
  }

  // MARK: - Objective-C support

  @objc(loginWithUsername:password:)
  func loginGeneric(username: String, password: String) -> AnyPromise {
    AnyPromise(login(username: username, password: password))
  }

  @objc
  class func errorDescription(_ err: WaniKaniWebClientError) -> String {
    err.localizedDescription
  }

  // MARK: - Extracting things from HTTP responses

  private func extractCSRFToken(_ data: Data) throws -> String {
    guard let ret = kCSRFTokenRE.firstCapturingGroup(in: data) else {
      throw WaniKaniWebClientError.csrfTokenNotFound
    }
    return ret
  }

  private func extractApiToken(_ data: Data) -> String? {
    guard let ret = kApiTokenRE.firstCapturingGroup(in: data) else {
      return nil
    }
    return ret
  }

  private func extractEmail(_ data: Data) throws -> String {
    guard let ret = kEmailRE.firstCapturingGroup(in: data) else {
      throw WaniKaniWebClientError.emailNotFound
    }
    return ret
  }

  private func getSessionCookie(_ session: URLSession) throws -> String {
    for cookie in session.configuration.httpCookieStorage?.cookies ?? [] {
      if cookie.name == kWanikaniSessionCookieName {
        return cookie.value
      }
    }
    throw WaniKaniWebClientError.sessionCookieNotSet
  }

  private func authorize(_ url: URL, cookie: String) -> URLRequest {
    var req = URLRequest(url: url)
    req.addValue("\(kWanikaniSessionCookieName)=\(cookie)", forHTTPHeaderField: "Cookie")
    return req
  }
}

typealias DataTaskPromise = Promise<(data: Data, response: URLResponse)>

private let kWanikaniSessionCookieName = "_wanikani_session"
private let kAccountUrl = URL(string: "https://www.wanikani.com/settings/account")!
private let kAccessTokenUrl =
  URL(string: "https://www.wanikani.com/settings/personal_access_tokens")!
private let kNewAccessTokenUrl =
  URL(string: "https://www.wanikani.com/settings/personal_access_tokens/new")!
private let kLoginUrl = URL(string: "https://www.wanikani.com/login")!
private let kDashboardUrl = URL(string: "https://www.wanikani.com/dashboard")!

private let kCSRFTokenRE = try! NSRegularExpression(pattern:
  "<meta name=\"csrf-token\" content=\"([^\"]*)", options: [])
private let kApiTokenRE = try! NSRegularExpression(pattern:
  "personal-access-token-description\">\\s*" +
    "Tsurukame\\s*" +
    "</td>\\s*" +
    "<td class=\"personal-access-token-token\">\\s*" +
    "<code>([a-f0-9-]{36})</code>", options: [])
private let kEmailRE = try! NSRegularExpression(pattern:
  "<input[^>]+value=\"([^\"]+)\"[^>]+id=\"user_email\"")

private func request(_ req: URLRequest,
                     session: URLSession = URLSession.shared) -> DataTaskPromise {
  NSLog("%@ %@", req.httpMethod!, req.url!.absoluteString)
  return session.dataTask(.promise, with: req)
}
