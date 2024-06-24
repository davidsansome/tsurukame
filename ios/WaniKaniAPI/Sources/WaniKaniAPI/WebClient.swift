// Copyright 2024 David Sansome
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
import PMKFoundation
import PromiseKit

public enum WaniKaniWebClientError: Int, LocalizedError {
  case csrfTokenNotFound
  case apiTokenNotFound
  case emailNotFound
  case sessionCookieNotSet
  case badCredentials
  case unknown

  public var errorDescription: String? {
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
      return "Incorrect email or password"
    default:
      return "Unknown error"
    }
  }
}

public struct LoginResult {
  public let cookie: String
  public let apiToken: String
}

public class WaniKaniWebClient: NSObject {
  // MARK: - Login

  /**
   * Login to WaniKani using the email and password, then fetch the user's
   * API token (creating a new one if it didn't exist) and email address.
   */
  public func login(email: String, password: String) -> Promise<LoginResult> {
    let cookie = getCookie(email: email, password: password)
    let token = cookie.then { cookie in
      self.getApiToken(cookie: cookie)
    }

    return when(fulfilled: [cookie, token]).map { arg in
      LoginResult(cookie: arg[0], apiToken: arg[1])
    }
  }

  private func getCookie(email: String, password: String) -> Promise<String> {
    let session = URLSession(configuration: .ephemeral)
    var firstCookie: String?
    var secondCookie: String?

    return firstly { () -> DataTaskPromise in
      // Make a request to the login page to get the CSRF token.
      var req = URLRequest(url: kLoginUrl)
      req.httpShouldHandleCookies = true
      return request(req, session: session)
    }.then { arg -> DataTaskPromise in
      // Extract the CSRF token and session cookie from the response.

      let csrfToken = try self.extractCSRFToken(arg.data)
      firstCookie = try self.getSessionCookie(session)

      // Build the login request.
      let queryItems = [
        URLQueryItem(name: "user[email]", value: email),
        URLQueryItem(name: "user[password]", value: password),
        URLQueryItem(name: "user[remember_me]", value: "0"),
        URLQueryItem(name: "authenticity_token", value: csrfToken),
      ]

      var req = URLRequest(url: kLoginUrl)
      req.httpShouldHandleCookies = true
      try req.setFormBody(method: "POST", queryItems: queryItems)
      return request(req, session: session)
    }.map { arg in
      secondCookie = try self.getSessionCookie(session)
      if firstCookie == secondCookie {
        throw WaniKaniWebClientError.badCredentials
      }
      if arg.response.url! == kLoginUrl,
         arg.data.range(of: "Invalid login or password".data(using: .utf8)!) != nil {
        throw WaniKaniWebClientError.badCredentials
      }
      return secondCookie!
    }
  }

  private func getApiToken(cookie: String) -> Promise<String> {
    firstly { () -> DataTaskPromise in
      let req = authorize(kAccessTokenUrl, cookie: cookie)
      return request(req, session: URLSession.shared)
    }.then { arg -> Promise<String> in
      if let apiToken = self.extractApiToken(arg.data) {
        return Promise.value(apiToken)
      }

      // No API token was found - we need to create one.
      return self.createApiToken(cookie: cookie)
    }
  }

  private func createApiToken(cookie: String) -> Promise<String> {
    firstly { () -> DataTaskPromise in
      let req = authorize(kAccessTokenUrl, cookie: cookie)
      return request(req)
    }.then { arg -> DataTaskPromise in
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

      var req = self.authorize(kAccessTokenUrl, cookie: cookie)
      try req.setFormBody(method: "POST", queryItems: queryItems)
      return request(req)
    }.map { arg throws -> String in
      if let apiToken = self.extractApiToken(arg.data) {
        return apiToken
      }
      throw WaniKaniWebClientError.apiTokenNotFound
    }
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
