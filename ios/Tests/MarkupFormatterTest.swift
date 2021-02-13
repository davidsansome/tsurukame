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

class MarkupFormatterTest: XCTestCase {
  func testNestedTags() {
    let text = parseFormattedText("a[ja]b[b]c[i]d[/i]e[/b]f[/ja]g")
    XCTAssertEqual(text.count, 7)

    XCTAssertEqual(text[0], try! TKMFormattedText(textFormatString: """
      text: "a"
    """))
    XCTAssertEqual(text[1], try! TKMFormattedText(textFormatString: """
      format: JAPANESE
      text: "b"
    """))
    XCTAssertEqual(text[2], try! TKMFormattedText(textFormatString: """
      format: JAPANESE
      format: BOLD
      text: "c"
    """))
    XCTAssertEqual(text[3], try! TKMFormattedText(textFormatString: """
      format: JAPANESE
      format: BOLD
      format: ITALIC
      text: "d"
    """))
    XCTAssertEqual(text[4], try! TKMFormattedText(textFormatString: """
      format: JAPANESE
      format: BOLD
      text: "e"
    """))
    XCTAssertEqual(text[5], try! TKMFormattedText(textFormatString: """
      format: JAPANESE
      text: "f"
    """))
    XCTAssertEqual(text[6], try! TKMFormattedText(textFormatString: """
      text: "g"
    """))
  }

  func testLinkTag() {
    let text = parseFormattedText("foo<a href=\"bar\">baz</a>")
    XCTAssertEqual(text.count, 2)

    XCTAssertEqual(text[0], try! TKMFormattedText(textFormatString: """
      text: "foo"
    """))
    XCTAssertEqual(text[1], try! TKMFormattedText(textFormatString: """
      format: LINK
      text: "baz"
      link_url: "bar"
    """))
  }
}
