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
  private func parse(_ text: String) -> TKMVocabulary {
    let ret = TKMVocabulary()
    ret.formattedMeaningExplanationArray = parseFormattedText(text)
    return ret
  }

  func testNestedTags() {
    assertProtoEquals(parse("a[ja]b[b]c[i]d[/i]e[/b]f[/ja]g"), """
    formatted_meaning_explanation {
      text: "a"
    }
    formatted_meaning_explanation {
      format: JAPANESE
      text: "b"
    }
    formatted_meaning_explanation {
      format: JAPANESE
      format: BOLD
      text: "c"
    }
    formatted_meaning_explanation {
      format: JAPANESE
      format: BOLD
      format: ITALIC
      text: "d"
    }
    formatted_meaning_explanation {
      format: JAPANESE
      format: BOLD
      text: "e"
    }
    formatted_meaning_explanation {
      format: JAPANESE
      text: "f"
    }
    formatted_meaning_explanation {
      text: "g"
    }
    """)
  }

  func testLinkTag() {
    assertProtoEquals(parse("foo<a href=\"bar\">baz</a>"), """
    formatted_meaning_explanation {
      text: "foo"
    }
    formatted_meaning_explanation {
      format: LINK
      text: "baz"
      link_url: "bar"
    }
    """)
  }
}
