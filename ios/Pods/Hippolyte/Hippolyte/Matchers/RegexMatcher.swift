//
//  Copyright © 2019 Jan Gorman. All rights reserved.
//

import Foundation

public final class RegexMatcher: Matcher {

  let regex: NSRegularExpression

  public init(regex: NSRegularExpression) {
    self.regex = regex
  }

  public override func matches(string: String?) -> Bool {
    guard let string = string else {
      return false
    }
    return regex.numberOfMatches(in: string, options: [], range: NSRange(string.startIndex..., in: string)) > 0
  }

  public override func hash(into hasher: inout Hasher) {
    hasher.combine(regex)
  }

  public override func isEqual(to other: Matcher) -> Bool {
    if let theOther = other as? RegexMatcher {
      return theOther.regex == regex
    }
    return false
  }

}
