// Copyright 2021 David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

extension NSRegularExpression {
  // Returns the capturing groups of the regex's first match in the text.
  func capturingGroups(in text: String) -> [String]? {
    let nsString = text as NSString
    guard let result = firstMatch(in: text,
                                  options: [],
                                  range: NSMakeRange(0, nsString.length)) else {
      return nil
    }
    var ret = [String]()
    for i in 0 ..< result.numberOfRanges {
      ret.append(nsString.substring(with: result.range(at: i)))
    }
    return ret
  }

  // Returns the first capturing group in the regex's first match in the text.
  func firstCapturingGroup(in data: Data) -> String? {
    let str = String(data: data, encoding: .utf8)!
    guard let groups = capturingGroups(in: str) else {
      return nil
    }
    return groups[1]
  }
}
