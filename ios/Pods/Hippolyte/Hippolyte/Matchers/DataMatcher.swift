//
//  Copyright © 2019 Jan Gorman. All rights reserved.
//

import Foundation

public final class DataMatcher: Matcher {
    
  let data: Data

  public init(data: Data) {
    self.data = data
  }

  public override func matches(data: Data?) -> Bool {
    self.data == data
  }

  public override func hash(into hasher: inout Hasher) {
    hasher.combine(data)
  }

  public override func isEqual(to other: Matcher) -> Bool {
    if let theOther = other as? DataMatcher {
      return theOther.data == data
    }
    return false
  }

}
