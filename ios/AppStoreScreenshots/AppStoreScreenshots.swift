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

import XCTest

class AppStoreScreenshots: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false

    app = XCUIApplication()
    setupSnapshot(app, waitForAnimations: false)
    app.launch()
  }

  override func tearDown() {
    // Stop the app, then run it again and tell it to clear its settings.
    app.terminate()
    app.launchArguments.append("ResetUserDefaults")
    app.launch()
  }

  // TODO(dsansome): Enable when the FakeLocalCachingClient contains the subjects that are being
  // searched for here.
  // Subject IDs: 743 3163 3164 355 1600 8911 8918 1787 1803 6556 1892 3516 3515 5907 6163 6812 6960
  // 6961
  func skip_testAppStoreScreenshots() {
    Thread.sleep(forTimeInterval: 1.0) // Wait for the profile photo to be downloaded.

    // Snapshot the home screen
    snapshot("01_home_screen")

    // Snapshot a search results page
    app.tables.buttons["Search"].tap()
    let search = app.searchFields["Search"]
    search.typeText("sake\n")
    Thread.sleep(forTimeInterval: 0.5)
    snapshot("04_search")
    search.tap()
    search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))

    // Select a subject and snapshot the subject details
    search.typeText("person")
    app.tables["Search results"].staticTexts["私自身"].tap()
    snapshot("02_subject_details")
    app.buttons["Back"].tap()

    // Catalogue view
    app.tables.staticTexts["Show all"].tap()
    snapshot("05_catalogue")
    app.navigationBars["Level 24"].buttons["Back"].tap()

    // Lessons view
    app.tables.staticTexts["Reviews"].tap()
    snapshot("02_lesson")
  }
}
