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

/** Keeps track of closure-based NotificationCenter observers and removes them all when the object
 *  is deallocated. */
class NotificationDispatcher {
  private let nc = NotificationCenter.default
  private var observers = [NSObjectProtocol]()

  /** Adds a new observer. You MUST take a weak reference to `self` in the handler. */
  func add(name: NSNotification.Name, sender: Any? = nil,
           using handler: @escaping (Notification) -> Void) {
    observers.append(nc.addObserver(forName: name, object: sender, queue: nil, using: handler))
  }

  deinit {
    for observer in observers {
      nc.removeObserver(observer)
    }
    observers.removeAll()
  }
}
