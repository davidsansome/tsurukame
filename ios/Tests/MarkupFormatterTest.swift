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

    assertProtoEquals(text[0], """
    text: "a"
    """)
    assertProtoEquals(text[1], """
    format: JAPANESE
    text: "b"
    """)
    assertProtoEquals(text[2], """
    format: JAPANESE
    format: BOLD
    text: "c"
    """)
    assertProtoEquals(text[3], """
    format: JAPANESE
    format: BOLD
    format: ITALIC
    text: "d"
    """)
    assertProtoEquals(text[4], """
    format: JAPANESE
    format: BOLD
    text: "e"
    """)
    assertProtoEquals(text[5], """
    format: JAPANESE
    text: "f"
    """)
    assertProtoEquals(text[6], """
    text: "g"
    """)
  }

  func testLinkTag() {
    let text = parseFormattedText("foo<a href=\"bar\">baz</a>")
    XCTAssertEqual(text.count, 2)

    assertProtoEquals(text[0], """
    text: "foo"
    """)
    assertProtoEquals(text[1], """
    format: LINK
    text: "baz"
    link_url: "bar"
    """)
  }
}
