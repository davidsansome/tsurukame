// Copyright 2023 David Sansome
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

import XCTest

class StringSHA256Test: XCTestCase {
  func testEmptyString() {
    XCTAssertEqual(String().sha256(),
                   "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  }

  func testNonEmptyString() {
    XCTAssertEqual("foo".sha256(),
                   "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae")
  }
}
