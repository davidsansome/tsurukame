//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

public protocol HTTPClientHook {
  func load()
  func unload()
  func isEqual(to other: HTTPClientHook) -> Bool
}

extension HTTPClientHook where Self: Equatable {
  
  func isEqual(to other: HTTPClientHook) -> Bool {
    if let theOther = other as? Self {
      return theOther == self
    }
    return false
  }
  
}

func ==(lhs: HTTPClientHook, rhs: HTTPClientHook) -> Bool {
  lhs.isEqual(to: rhs)
}
