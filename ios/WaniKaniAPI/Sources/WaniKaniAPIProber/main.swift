// Copyright 2024 David Sansome
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
import PromiseKit
import WaniKaniAPI

if CommandLine.arguments.count != 3 {
  print("Usage: \(CommandLine.arguments[0]) EMAIL PASSWORD")
  exit(1)
}
let email = CommandLine.arguments[1]
let password = CommandLine.arguments[2]

let queue = DispatchQueue.global()
let semaphore = DispatchSemaphore(value: 0)

PromiseKit.conf.Q.map = queue
PromiseKit.conf.Q.return = queue

let client = WaniKaniWebClient()
var exitCode: Int32 = 0
firstly {
  client.login(email: email, password: password)
}.done { result in
  print("Login successful")
}.catch { error in
  print("Login failed: ", error)
  exitCode = 1
}.finally {
  semaphore.signal()
}

semaphore.wait()
exit(exitCode)
