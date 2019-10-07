// Copyright 2019 David Sansome
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

class FontScreenshotterUITests: XCTestCase {
  let app: XCUIApplication = XCUIApplication()

  override func setUp() {
    continueAfterFailure = false
    app.launch()
  }

  func testScreenshotFontPreviews() {
    // Find all the font preview elements.
    let elements = app.tables.cells.staticTexts.matching(identifier: "preview")
    for i in 0 ... elements.count {
      let element = elements.element(boundBy: i)
      if !element.exists {
        continue
      }

      let s = XCTAttachment(screenshot: element.screenshot())
      s.lifetime = XCTAttachment.Lifetime.keepAlways
      s.name = element.label // The label is the font name.
      add(s)
    }
  }
}
