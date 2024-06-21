//
//  Copyright © 2019 Jan Gorman. All rights reserved.
//

import Foundation

public final class JSONMatcher<T: Decodable & Hashable>: Matcher {

  let decoder: JSONDecoder
  let object: T

  public init(object: T) {
    self.decoder = JSONDecoder()
    self.object = object
  }

  public override func matches(data: Data?) -> Bool {
    guard let data = data, let decodedObject = try? self.decoder.decode(T.self, from: data) else {
      return false
    }
    return object == decodedObject
  }

  public override func hash(into hasher: inout Hasher) {
    hasher.combine(object)
  }

  public override func isEqual(to other: Matcher) -> Bool {
    if let theOther = other as? JSONMatcher<T> {
      return theOther.object == object
    }
    return false
  }

}
