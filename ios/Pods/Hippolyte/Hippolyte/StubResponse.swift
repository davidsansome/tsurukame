//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

public protocol HTTPStubResponse {
  var statusCode: Int { get }
  var headers: [String: String] { get }
  var body: Data? { get }
}

public struct StubResponse: HTTPStubResponse, Equatable {

  public final class Builder {

    private var response: StubResponse!

    public init() {
    }

    @discardableResult
    public func defaultResponse() -> Builder {
      response = StubResponse()
      return self
    }

    @discardableResult
    public func stubResponse(withStatusCode statusCode: Int) -> Builder {
      response = StubResponse(statusCode: statusCode)
      return self
    }

    @discardableResult
    public func stubResponse(withError error: NSError) -> Builder {
      response = StubResponse(error: error)
      return self
    }

    @discardableResult
    public func addBody(_ body: Data) -> Builder {
      assert(response != nil)
      response.body = body
      return self
    }

    @discardableResult
    public func addHeader(withKey key: String, value: String) -> Builder {
      assert(response != nil)
      response.headers[key] = value
      return self
    }

    public func build() -> StubResponse {
      response
    }

  }

  public var statusCode: Int
  public var headers: [String : String]
  public var body: Data?
  public let shouldFail: Bool
  public let error: NSError?

  /// Initialize a default response with statusCode 200 and empty body
  public init() {
    self.init(statusCode: 200)
  }

  /// Initialize a response with error to return
  ///
  /// - Parameter error: `NSError` to return when stubbing
  public init(error: NSError) {
    statusCode = -1
    headers = [:]
    body = nil
    shouldFail = true
    self.error = error
  }

  /// Initialize a response with a different statusCode
  ///
  /// - Parameter statusCode: The statusCode to use when stubbing
  public init(statusCode: Int) {
    self.statusCode = statusCode
    body = Data("".utf8)
    headers = [:]
    shouldFail = false
    error = nil
  }

}
