//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

protocol Matcheable {
  func matcher() -> Matcher
}

extension URL: Matcheable {
  
  func matcher() -> Matcher {
    StringMatcher(string: absoluteString)
  }
  
}
