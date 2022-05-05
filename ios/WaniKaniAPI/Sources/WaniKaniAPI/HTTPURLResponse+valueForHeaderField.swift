// Copyright 2022 David Sansome
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

public extension HTTPURLResponse {
  func valueForHeaderField(_ headerField: String) -> String? {
    if #available(iOS 13.0, *) {
      return value(forHTTPHeaderField: headerField)
    } else {
      let lowerHeaderField = headerField.lowercased()
      return allHeaderFields.first { key, _ in
        (key as! String).lowercased() == lowerHeaderField
      } as! String?
    }
  }
}
