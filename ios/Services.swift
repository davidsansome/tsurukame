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
import Reachability

@objc
@objcMembers
class TKMServices: NSObject {
  let reachability: Reachability
  let fontLoader: TKMFontLoader

  private(set) var audio: Audio!
  var client: WaniKaniAPIClient!
  var localCachingClient: LocalCachingClient!

  override init() {
    reachability = Reachability.forInternetConnection()
    fontLoader = TKMFontLoader()

    super.init()

    audio = Audio(services: self)
  }
}
