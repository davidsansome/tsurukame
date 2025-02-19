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

class RecentMistakesTest: XCTestCase {
  func testEmptyMergeGivesNothing() {
    let output = RecentMistakeHandler.mergeMistakes(original: [Int32: Date](),
                                                    other: [Int32: Date]())
    XCTAssertEqual(0, output.count)
  }

  func testMergeMistakesOneArrayOnly() {
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -10, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let mistakes = [Int32(42): firstDate, Int32(44): secondDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: [Int32: Date]())
    XCTAssertEqual(2, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: [Int32: Date](), other: mistakes)
    XCTAssertEqual(2, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
  }

  func testOldDatesRemoved() {
    // dates older than 24 hrs should be removed
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -42, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -88, to: now)!
    let thirdDate = Calendar.current.date(byAdding: .hour, value: -33, to: now)!
    let mistakes = [Int32(42): firstDate, Int32(44): secondDate]
    let otherMistakes = [Int32(41): thirdDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(0, output.count)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(0, output.count)
  }

  func testSimpleMergeTwoDiffDatasets() {
    // simple merge of two sets with two different pieces of data
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -10, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let mistakes = [Int32(42): firstDate]
    let otherMistakes = [Int32(44): secondDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(2, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(2, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
  }

  func testSimpleMergeSameDataDatasets() {
    // simple merge of two sets with same pieces of data
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -10, to: now)!
    let mistakes = [Int32(42): firstDate]
    let otherMistakes = [Int32(42): firstDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(1, output.count)
    XCTAssertEqual(output[42], firstDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(1, output.count)
    XCTAssertEqual(output[42], firstDate)
  }

  func testSimpleMergeSameDatasetsMultipleSubjects() {
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -10, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let mistakes = [Int32(42): firstDate, Int32(44): secondDate]
    let otherMistakes = [Int32(42): firstDate, Int32(44): secondDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(2, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(2, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
  }

  func testSubjectIdConflictMerge() {
    // we expect to get the newer date when there is a date conflict
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -10, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let mistakes = [Int32(42): firstDate]
    let otherMistakes = [Int32(42): secondDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(1, output.count)
    XCTAssertEqual(output[42], secondDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(1, output.count)
    XCTAssertEqual(output[42], secondDate)
  }

  func testSubjectIdConflictMergeMultipleSubjects() {
    // we expect to get the newer date when there is a date conflict
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -10, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let thirdDate = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
    let mistakes = [Int32(42): firstDate, Int32(44): firstDate, Int32(46): thirdDate]
    let otherMistakes = [Int32(42): secondDate, Int32(46): firstDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(3, output.count)
    XCTAssertEqual(output[42], secondDate)
    XCTAssertEqual(output[44], firstDate)
    XCTAssertEqual(output[46], thirdDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(3, output.count)
    XCTAssertEqual(output[42], secondDate)
    XCTAssertEqual(output[44], firstDate)
    XCTAssertEqual(output[46], thirdDate)
  }

  func testSameDateDifferentSubjectsMerge() {
    // we expect to get the newer date when there is a date conflict
    let now = Date()
    let firstDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let secondDate = Calendar.current.date(byAdding: .hour, value: -4, to: now)!
    let mistakes = [Int32(42): firstDate]
    let otherMistakes = [Int32(44): secondDate, Int32(46): secondDate]
    var output = RecentMistakeHandler.mergeMistakes(original: mistakes, other: otherMistakes)
    XCTAssertEqual(3, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
    XCTAssertEqual(output[46], secondDate)
    // ensure that flopping the dictionaries gets same output
    output = RecentMistakeHandler.mergeMistakes(original: otherMistakes, other: mistakes)
    XCTAssertEqual(3, output.count)
    XCTAssertEqual(output[42], firstDate)
    XCTAssertEqual(output[44], secondDate)
    XCTAssertEqual(output[46], secondDate)
  }
}
