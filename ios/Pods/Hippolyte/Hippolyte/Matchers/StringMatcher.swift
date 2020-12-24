//
//  Copyright © 2019 Jan Gorman. All rights reserved.
//

import Foundation

public final class StringMatcher: Matcher {

  let string: String

  public init(string: String) {
    self.string = string
  }

  public override func matches(string: String?) -> Bool {
    self.string == string
  }

  public override func matches(data: Data?) -> Bool {
    self.string.data(using: .utf8) == data
  }

  public override func hash(into hasher: inout Hasher) {
    hasher.combine(string)
  }

  public override func isEqual(to other: Matcher) -> Bool {
    if let theOther = other as? StringMatcher {
      return theOther.string == string
    }
    return false
  }

}
