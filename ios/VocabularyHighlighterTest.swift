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

class VocabularyHighlighterTest: XCTestCase {
  var dataLoader: DataLoader!

  override func setUp() {
    dataLoader = try! DataLoader(fromURL: Bundle.main.url(forResource: "data", withExtension: "bin")!)
  }

  func testHighlightsAllSubjects() {
    for subject in dataLoader.loadAll() {
      if !subject.hasVocabulary {
        continue
      }

      for sentence in subject.vocabulary.sentencesArray as! [TKMVocabulary_Sentence] {
        let text = highlightOccurrences(of: subject, in: sentence.japanese)
        if text == nil {
          let pattern = patternToHighlight(for: subject)
          XCTAssertNotNil(text, "No match of \(pattern) in \(sentence.japanese!): \(subject.vocabulary.commaSeparatedPartsOfSpeech)")
        }
      }
    }
  }
}
