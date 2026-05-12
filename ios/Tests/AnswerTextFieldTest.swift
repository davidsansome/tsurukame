// Copyright 2025 David Sansome
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

private class SpyAnswerTextField: AnswerTextField {
  var resignCount = 0
  override func resignFirstResponder() -> Bool {
    resignCount += 1
    return super.resignFirstResponder()
  }
}

class AnswerTextFieldTest: XCTestCase {
  var window: UIWindow!
  var field: SpyAnswerTextField!

  override func setUp() {
    super.setUp()
    field = SpyAnswerTextField()
    window = UIWindow(frame: UIScreen.main.bounds)
    window.addSubview(field)
    window.makeKeyAndVisible()
    field.becomeFirstResponder()
  }

  override func tearDown() {
    field.resignFirstResponder()
    window = nil
    field = nil
    super.tearDown()
  }

  func testSwitchingLanguageDoesNotDismissKeyboard() {
    XCTAssertTrue(field.isFirstResponder, "precondition: field must be first responder")
    field.useJapaneseKeyboard = true
    XCTAssertEqual(field.resignCount, 0, "keyboard should not be dismissed when switching language")
    XCTAssertTrue(field.isFirstResponder, "field should remain first responder after language switch")
  }
}
