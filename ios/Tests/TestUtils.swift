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

import PromiseKit
import XCTest

/** Asserts the text format of the given proto message equals the given string. */
func assertProtoEquals(_ actual: GPBMessage,
                       _ expected: String,
                       file: StaticString = #file,
                       line: UInt = #line) {
  // Objective C's protobuf library doesn't include a text format parser, so we have to go the other
  // way instead.
  let actualTrimmed = GPBTextFormatForMessage(actual, nil)
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
  XCTAssert(actualTrimmed == expectedTrimmed,
            "assertProtoEquals failed:\nActual:\n\(actualTrimmed)\n\nExpected:\n\(expectedTrimmed)",
            file: file, line: line)
}

/**
 * Waits for the promise to be fulfilled and returns its value.
 * Fails the test if the promise rejects or if it doesn't complete within a 1 second timeout.
 */
func waitForPromise<T>(_ p: Promise<T>,
                       file: StaticString = #filePath,
                       line: UInt = #line) -> T? {
  let expectation = XCTestExpectation(description: "waitForPromise")
  var ret: T?
  p.done { result in
    ret = result
  }.catch { error in
    XCTFail("Promise failed: \(error.localizedDescription)", file: file, line: line)
  }.finally {
    expectation.fulfill()
  }

  let waitResult = XCTWaiter().wait(for: [expectation], timeout: 1)
  if waitResult != .completed {
    XCTFail("Promise never completed: \(waitResult.rawValue)", file: file, line: line)
  }
  return ret
}

/**
 * Waits for the promise to reject and returns its error.
 * Fails the test if the promise succeeds or if it doesn't complete within a 1 second timeout.
 */
func waitForError<T>(_ p: Promise<T>,
                     file: StaticString = #filePath,
                     line: UInt = #line) -> Error? {
  let expectation = XCTestExpectation(description: "waitForPromise")
  var ret: Error?
  p.done { _ in
    XCTFail("Promise succeeded unexpectedly")
  }.catch { error in
    ret = error
  }.finally {
    expectation.fulfill()
  }

  let waitResult = XCTWaiter().wait(for: [expectation], timeout: 100)
  if waitResult != .completed {
    XCTFail("Promise never completed: \(waitResult.rawValue)", file: file, line: line)
  }
  return ret
}
