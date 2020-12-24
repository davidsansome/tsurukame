// Copyright 2020 David Sansome
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

import MockURLSession
import XCTest

class APIClientTest: XCTestCase {
  var dataLoader: FakeDataLoader!
  var urlSession: URLSession!

  var client: WaniKaniAPIClient!

  override func setUp() {
    dataLoader = FakeDataLoader()
    urlSession = MockURLSession()

    client = WaniKaniAPIClient(apiToken: "token", dataLoader: dataLoader, urlSession: urlSession)
  }

  func testDateParsing() {
    let parse = { (_ str: String) -> Double in
      WaniKaniDate(fromString: str)!.date.timeIntervalSince1970
    }

    XCTAssertEqual(parse("2018-08-05T11:08:39.431000Z"), 1_533_467_319.431)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431Z"), 1_533_467_319.431)
    XCTAssertEqual(parse("2018-08-05T11:08:39.000000Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("2018-08-05T11:08:39.000Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("20180805T11:08:39.431000Z"), 1_533_467_319.431)
    XCTAssertEqual(parse("2018-08-05T11:08:39Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("20180805T11:08:39Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431000+03:00"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431000+0300"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431000+03"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431+03:00"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431+0300"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431+03"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39+03:00"), 1_533_467_319.0 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39+0300"), 1_533_467_319.0 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39+03"), 1_533_467_319.0 - 3 * 60 * 60)
  }
}
