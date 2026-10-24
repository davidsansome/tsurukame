#!/usr/bin/env swift

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

// Combines the similar kanji databases in this directory into the visually-similar-kanji.json
// resource used by the app. Run from anywhere with:
//   swift similar_kanji/generate.swift

import Foundation

let scoreThreshold: Float = 0.4

let inputDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputFile = inputDirectory
  .appendingPathComponent("../ios/WaniKaniAPI/Sources/WaniKaniAPI/Resources/visually-similar-kanji.json")
  .standardizedFileURL

struct Entry: Decodable {
  let kan: String
  var score: Float
}

// Similar kanji for each kanji, in the order they were first added.
var index = [String: [Entry]]()

func add(kanji: String, similarKanji: String, score: Float) {
  // If we have this similar kanji already, upgrade its score if the new one is higher, otherwise
  // skip it.
  if let existing = index[kanji]?.firstIndex(where: { $0.kan == similarKanji }) {
    index[kanji]![existing].score = max(index[kanji]![existing].score, score)
    return
  }
  index[kanji, default: []].append(Entry(kan: similarKanji, score: score))
}

func load<T: Decodable>(_ filename: String) throws -> [String: T] {
  let data = try Data(contentsOf: inputDirectory.appendingPathComponent(filename))
  return try JSONDecoder().decode([String: T].self, from: data)
}

func addUnscoredFile(_ filename: String) throws {
  for (kanji, entries) in try load(filename) as [String: [String]] {
    for entry in entries {
      add(kanji: kanji, similarKanji: entry, score: 1.0)
    }
  }
}

func addScoredFile(_ filename: String) throws {
  for (kanji, entries) in try load(filename) as [String: [Entry]] {
    for entry in entries where entry.score > scoreThreshold {
      add(kanji: kanji, similarKanji: entry.kan, score: entry.score)
    }
  }
}

try addUnscoredFile("from_keisei.json")
try addUnscoredFile("manual.json")
try addUnscoredFile("old_script.json")
try addScoredFile("stroke_edit_dist.json")
try addScoredFile("wk_niai_noto.json")
try addScoredFile("yl_radical.json")

// Most similar first.
var compact = [String: String]()
for (kanji, entries) in index {
  compact[kanji] = String(entries.sorted { $0.score > $1.score }.map(\.kan).joined())
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
var output = try encoder.encode(compact)
output.append(contentsOf: "\n".utf8)
try output.write(to: outputFile)
print("Wrote \(compact.count) kanji to \(outputFile.path)")
