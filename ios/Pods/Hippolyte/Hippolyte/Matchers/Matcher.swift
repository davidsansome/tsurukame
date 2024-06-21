//
//  Copyright © 2017 Jan Gorman. All rights reserved.
//

import Foundation

open class Matcher: Hashable {

  public init() {}

  open func matches(string: String?) -> Bool {
    false
  }

  open func matches(data: Data?) -> Bool {
    false
  }

  open func isEqual(to other: Matcher) -> Bool {
    false
  }

  open func hash(into hasher: inout Hasher) {
  }

  public static func ==(lhs: Matcher, rhs: Matcher) -> Bool {
    lhs.isEqual(to: rhs)
  }

}
