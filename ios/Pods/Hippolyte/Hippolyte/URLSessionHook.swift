//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

final class URLSessionHook: HTTPClientHook {

  func isEqual(to other: HTTPClientHook) -> Bool {
    if let theOther = other as? URLSessionHook {
      return theOther == self
    }
    return false
  }

  func load() {
    guard let method = class_getInstanceMethod(originalClass(), originalSelector()),
          let stub = class_getInstanceMethod(URLSessionHook.self, #selector(protocolClasses)) else {
      fatalError("Could not load URLSessionHook")
    }
    method_exchangeImplementations(method, stub)
  }

  private func originalClass() -> AnyClass? {
    NSClassFromString("__NSCFURLSessionConfiguration") ?? NSClassFromString("NSURLSessionConfiguration")
  }

  private func originalSelector() -> Selector {
    #selector(getter: URLSessionConfiguration.protocolClasses)
  }

  @objc
  private func protocolClasses() -> [AnyClass] {
    [HTTPStubURLProtocol.self]
  }

  func unload() {
    load()
  }

}
