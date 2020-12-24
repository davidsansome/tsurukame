//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

public enum HTTPMethod: String {
  case GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH
}

public struct StubRequest: Hashable {

  public final class Builder {

    private var request: StubRequest!

    public init() {
    }

    @discardableResult
    public func stubRequest(withMethod method: HTTPMethod, url: URL) -> Builder {
      request = StubRequest(method: method, url: url)
      return self
    }

    @discardableResult
    public func stubRequest(withMethod method: HTTPMethod, urlMatcher: Matcher) -> Builder {
      request = StubRequest(method: method, urlMatcher: urlMatcher)
      return self
    }

    @discardableResult
    public func addHeader(withKey key: String, value: String) -> Builder {
      assert(request != nil)
      request.setHeader(key: key, value: value)
      return self
    }

    @discardableResult
    public func addResponse(_ response: StubResponse) -> Builder {
      assert(request != nil)
      request.response = response
      return self
    }

    @discardableResult
    public func addMatcher(_ matcher: Matcher) -> Builder {
      assert(request != nil)
      request.bodyMatcher = matcher
      return self
    }

    public func build() -> StubRequest {
      request
    }

  }

  public let method: HTTPMethod
  public private(set) var headers: [String: String]
  public var response: StubResponse
  public var bodyMatcher: Matcher?

  private let urlMatcher: Matcher

  /// Initialize a request with method and URL
  ///
  /// - Parameters:
  ///   - method: The `HTTPMethod` to match
  ///   - url: The `URL` to match
  public init(method: HTTPMethod, url: URL) {
    self.init(method: method, urlMatcher: url.matcher())
  }

  /// Initialize a request with method and `Matcher`
  ///
  /// - Parameters:
  ///   - method: The `HTTPMethod` to match
  ///   - urlMatcher: The `Matcher` to use for URLs
  public init(method: HTTPMethod, urlMatcher: Matcher) {
    self.method = method
    self.urlMatcher = urlMatcher
    self.headers = [:]
    self.response = StubResponse()
  }

  public func matchesRequest(_ request: HTTPRequest) -> Bool {
    request.method == method && matchesUrl(request.url) && matchesHeaders(request.headers) && matchesBody(request.body)
  }

  private func matchesUrl(_ url: URL?) -> Bool {
    urlMatcher.matches(string: url?.absoluteString)
  }

  private func matchesHeaders(_ headersToMatch: [String: String]?) -> Bool {
    guard let headersToMatch = headersToMatch else {
      return headers.isEmpty
    }
    for key in headers.keys {
      guard let value = headersToMatch[key] else {
        return false
      }
      if value != headers[key] {
        return false
      }
    }
    return true
  }

  private func matchesBody(_ body: Data?) -> Bool {
    guard let bodyMatcher = bodyMatcher, let body = body else {
      return true
    }
    return bodyMatcher.matches(data: body)
  }

  public mutating func setHeader(key: String, value: String) {
    headers[key] = value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(method)
    hasher.combine(urlMatcher)
    hasher.combine(bodyMatcher)
    hasher.combine(headers)
  }

  public static func ==(lhs: StubRequest, rhs: StubRequest) -> Bool {
    lhs.method == rhs.method && lhs.urlMatcher == rhs.urlMatcher && lhs.headers == rhs.headers && lhs.bodyMatcher == rhs.bodyMatcher
  }

}
