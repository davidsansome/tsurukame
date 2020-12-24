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

  override func startLoading() {
    guard let stubbedResponse = try? Hippolyte.shared.response(for: request), let url = request.url else {
      client?.urlProtocol(self, didFailWithError: NoMatchError(request: request))
      return
    }

    let cookieStorage = HTTPCookieStorage.shared
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
