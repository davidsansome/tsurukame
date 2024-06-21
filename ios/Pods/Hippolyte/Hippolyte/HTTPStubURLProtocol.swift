//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

final class HTTPStubURLProtocol: URLProtocol {

  struct NoMatchError: Swift.Error, CustomStringConvertible {
    let request: URLRequest
    
    var description: String {
      "No matching stub found for \(request)"
    }
  }

  override class func canInit(with request: URLRequest) -> Bool {
    guard let scheme = request.url?.scheme else { return false }
    return ["http", "https"].contains(scheme)
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
    false
  }

  private var urlSessionTask: URLSessionTask?

  @available(iOS 8, *)
  init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
    super.init(request: task.currentRequest!, cachedResponse: cachedResponse, client: client)
    self.urlSessionTask = task
  }

  @available(iOS 8, *)
  override var task: URLSessionTask? {
    urlSessionTask
  }

  override func startLoading() {
    var request = self.request

    // Get the cookie storage that applies to this request. We can only do this on iOS >= 8.0 which
    // gives us access to the URLSessionTask and its configuration.
    var cookieStorage = HTTPCookieStorage.shared
    if #available(iOS 8, *),
       let session = task?.value(forKey: "session") as? URLSession,
       let configurationCookieStorage = session.configuration.httpCookieStorage {
      cookieStorage = configurationCookieStorage
    }

    // Get the cookies that apply to this URL and add them to the request headers.
    if let url = request.url, let cookies = cookieStorage.cookies(for: url) {
      if request.allHTTPHeaderFields == nil {
        request.allHTTPHeaderFields = [String: String]()
      }
      request.allHTTPHeaderFields!.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in current }
    }

    // Find the stubbed response for this request.
    guard let stubbedResponse = try? Hippolyte.shared.response(for: request), let url = request.url else {
      client?.urlProtocol(self, didFailWithError: NoMatchError(request: request))
      return
    }

    cookieStorage.setCookies(HTTPCookie.cookies(withResponseHeaderFields: stubbedResponse.headers, for: url),
                             for: url, mainDocumentURL: url)
    if stubbedResponse.shouldFail {
      client?.urlProtocol(self, didFailWithError: stubbedResponse.error!)
    } else {
      let statusCode = stubbedResponse.statusCode
      let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil,
                                     headerFields: stubbedResponse.headers)

      if 300...399 ~= statusCode && (statusCode != 304 && statusCode != 305) {
        guard let location = stubbedResponse.headers["Location"], let url = URL(string: location),
              let cookies = cookieStorage.cookies(for: url) else {
          return
        }
        var redirect = URLRequest(url: url)
        redirect.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)

        client?.urlProtocol(self, wasRedirectedTo: redirect, redirectResponse: response!)
      }

      let body = stubbedResponse.body
      client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: body!)
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {
  }

}
