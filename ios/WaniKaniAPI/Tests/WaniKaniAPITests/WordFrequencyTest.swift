// Copyright David Sansome
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

import WaniKaniAPI
import XCTest

class WordFrequencyTest: XCTestCase {
  func testForSubject() {
    // 大人 (vocabulary).
    let frequency = WordFrequency.forSubject(id: 2502)
    XCTAssertNotNil(frequency)
    XCTAssertTrue(frequency!.isCommon)
    XCTAssertNotNil(frequency!.rank)

    // ちょっと (kana-only vocabulary).
    XCTAssertNotNil(WordFrequency.forSubject(id: 9176)?.rank)

    // 一 (kanji), which has no frequency.
    XCTAssertNil(WordFrequency.forSubject(id: 440))
  }

  func testRankBand() {
    func band(_ rank: Int?) -> String? {
      WordFrequency(isCommon: false, rank: rank).rankBand
    }

    XCTAssertNil(band(nil))
    XCTAssertEqual(band(1), "Top 1k")
    XCTAssertEqual(band(1000), "Top 1k")
    XCTAssertEqual(band(1001), "1k – 2k")
    XCTAssertEqual(band(8500), "8k – 10k")
    XCTAssertEqual(band(10000), "8k – 10k")
    XCTAssertEqual(band(29380), "20k – 30k")
    XCTAssertEqual(band(50000), "30k – 50k")
    XCTAssertEqual(band(50001), "50k+")
  }
}
