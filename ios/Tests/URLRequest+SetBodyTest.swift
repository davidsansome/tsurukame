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

class URLRequestSetBodyTest: XCTestCase {
  func testEncodesPlusSign() {
    var req = URLRequest(url: URL(string: "http://example.com")!)
    try! req.setFormBody(method: "POST", queryItems: [
      URLQueryItem(name: "password", value: "foo+bar"),
    ])

    XCTAssertEqual(String(data: req.httpBody!, encoding: .utf8)!, "password=foo%2Bbar")
  }

  func testEncodesAmpersandAndEquals() {
    var req = URLRequest(url: URL(string: "http://example.com")!)
    try! req.setFormBody(method: "POST", queryItems: [
      URLQueryItem(name: "username", value: "bob=bob"),
      URLQueryItem(name: "password", value: "foo&bar"),
    ])

    XCTAssertEqual(String(data: req.httpBody!, encoding: .utf8)!,
                   "username=bob%3Dbob&password=foo%26bar")
  }

  func testEncodesPercentSign() {
    var req = URLRequest(url: URL(string: "http://example.com")!)
    try! req.setFormBody(method: "POST", queryItems: [
      URLQueryItem(name: "password", value: "foo%bar"),
    ])

    XCTAssertEqual(String(data: req.httpBody!, encoding: .utf8)!, "password=foo%25bar")
  }
}
