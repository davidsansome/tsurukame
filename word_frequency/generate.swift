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

// Generates the word-frequency.json resource used by the app, which says how common each WaniKani
// vocabulary subject is. Run from anywhere with:
//   swift word_frequency/generate.swift path/to/local-cache.db
//
// The vocabulary subjects are read from local-cache.db, a copy of the app's sqlite database. The
// JMdict, jiten.moe and wordfreq data files are downloaded into word_frequency/cache the first
// time.
//
// Each word's rank is the geometric mean of its ranks in the jiten.moe global list (mostly anime,
// drama and novels), the jiten.moe non-fiction list, and wordfreq (Wikipedia, subtitles, web text
// and social media). No one list is balanced between formal and casual Japanese, but together they
// are.

import Foundation
import SQLite3

let scriptDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let cacheDirectory = scriptDirectory.appendingPathComponent("cache")
let outputFile = scriptDirectory
  .appendingPathComponent("../ios/WaniKaniAPI/Sources/WaniKaniAPI/Resources/word-frequency.json")
  .standardizedFileURL

let jmdictURL = URL(string: "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz")!
let jitenGlobalURL =
  URL(string: "https://api.jiten.moe/api/frequency-list/download?downloadType=csv")!
let jitenNonFictionURL =
  URL(string: "https://api.jiten.moe/api/frequency-list/download?downloadType=csv&mediaType=5")!
let wordfreqURL =
  URL(string: "https://raw.githubusercontent.com/rspeer/wordfreq/master/wordfreq/data/large_ja.msgpack.gz")!

// JMdict priority tags that mark an entry as "common". See
// https://www.edrdg.org/jmwsgi/edhelp.py#kw_freq
let commonPriorities: Set<String> = ["news1", "ichi1", "spec1", "spec2", "gai1"]

// The value of Subject.Type.VOCABULARY in wanikani_api.proto.
let vocabularyType = 3

func fail(_ message: String) -> Never {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
  exit(1)
}

// MARK: - Downloads

func download(_ url: URL, to destination: URL) {
  print("Downloading \(url)")
  let semaphore = DispatchSemaphore(value: 0)
  var error: Error?
  URLSession.shared.downloadTask(with: url) { location, response, e in
    defer { semaphore.signal() }
    if let e = e {
      error = e
      return
    }
    if let response = response as? HTTPURLResponse, response.statusCode != 200 {
      error = NSError(domain: "HTTP", code: response.statusCode)
      return
    }
    do {
      try FileManager.default.moveItem(at: location!, to: destination)
    } catch let e {
      error = e
    }
  }.resume()
  semaphore.wait()
  if let error = error {
    fail("Failed to download \(url): \(error)")
  }
}

func cachedFile(_ name: String, from url: URL, gunzip: Bool = false) -> URL {
  let file = cacheDirectory.appendingPathComponent(name)
  if FileManager.default.fileExists(atPath: file.path) {
    return file
  }
  try! FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
  if !gunzip {
    download(url, to: file)
    return file
  }

  let gzFile = file.appendingPathExtension("gz")
  download(url, to: gzFile)
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
  process.arguments = [gzFile.path]
  try! process.run()
  process.waitUntilExit()
  if process.terminationStatus != 0 {
    fail("Failed to gunzip \(gzFile.path)")
  }
  return file
}

// MARK: - Reading vocabulary from the app's database

struct Vocabulary {
  let id: Int64
  let japanese: String
  let primaryReadings: [String]
}

// A minimal protobuf wire format reader, just enough to read the readings out of a Subject.
struct ProtoReader {
  let bytes: [UInt8]
  var offset = 0

  init(_ bytes: [UInt8]) {
    self.bytes = bytes
  }

  var atEnd: Bool { offset >= bytes.count }

  mutating func varint() -> UInt64 {
    var result: UInt64 = 0
    var shift: UInt64 = 0
    while true {
      let byte = bytes[offset]
      offset += 1
      result |= UInt64(byte & 0x7F) << shift
      if byte & 0x80 == 0 {
        return result
      }
      shift += 7
    }
  }

  // Returns the field number and its value. The value is the varint for wire type 0, and the bytes
  // for wire type 2. Other wire types are skipped and return nil.
  mutating func field() -> (Int, UInt64?, [UInt8]?) {
    let key = varint()
    let fieldNumber = Int(key >> 3)
    switch key & 7 {
    case 0:
      return (fieldNumber, varint(), nil)
    case 1:
      offset += 8
    case 2:
      let length = Int(varint())
      let value = Array(bytes[offset ..< offset + length])
      offset += length
      return (fieldNumber, nil, value)
    case 5:
      offset += 4
    default:
      fail("Unsupported protobuf wire type \(key & 7)")
    }
    return (fieldNumber, nil, nil)
  }
}

func primaryReadings(subjectProto: [UInt8]) -> [String] {
  var ret = [String]()
  var subject = ProtoReader(subjectProto)
  while !subject.atEnd {
    // Subject.readings is field 6.
    guard case let (6, _, readingBytes?) = subject.field() else { continue }

    var reading = ProtoReader(readingBytes)
    var text: String?
    var isPrimary = false
    while !reading.atEnd {
      switch reading.field() {
      case let (1, _, value?): text = String(decoding: value, as: UTF8.self)
      case let (2, value?, _): isPrimary = value != 0
      default: break
      }
    }
    if let text = text, isPrimary {
      ret.append(text)
    }
  }
  return ret
}

func readVocabulary(databasePath: String) -> [Vocabulary] {
  var db: OpaquePointer?
  guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
    fail("Failed to open \(databasePath)")
  }
  defer { sqlite3_close(db) }

  var statement: OpaquePointer?
  let sql = "SELECT id, japanese, pb FROM subjects WHERE type = \(vocabularyType) ORDER BY id"
  guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
    fail("Failed to query subjects: \(String(cString: sqlite3_errmsg(db)))")
  }
  defer { sqlite3_finalize(statement) }

  var ret = [Vocabulary]()
  while sqlite3_step(statement) == SQLITE_ROW {
    let id = sqlite3_column_int64(statement, 0)
    let japanese = String(cString: sqlite3_column_text(statement, 1))
    let length = Int(sqlite3_column_bytes(statement, 2))
    let pb = Array(UnsafeBufferPointer(start: sqlite3_column_blob(statement, 2)?
        .assumingMemoryBound(to: UInt8.self),
      count: length))
    ret.append(Vocabulary(id: id, japanese: japanese,
                          primaryReadings: primaryReadings(subjectProto: pb)))
  }
  return ret
}

// MARK: - JMdict

struct JMdictEntry {
  // Kanji spellings and whether each is common.
  var kanji = [(String, Bool)]()
  // Kana readings and whether each is common.
  var readings = [(String, Bool)]()
}

// JMdict has one XML element per line, so we read it line by line rather than parsing the XML.
func readJMdict(_ file: URL) -> [JMdictEntry] {
  let contents = try! String(contentsOf: file, encoding: .utf8)
  var entries = [JMdictEntry]()
  var entry = JMdictEntry()

  func text(of line: Substring, tag: String) -> String? {
    let open = "<\(tag)>", close = "</\(tag)>"
    guard line.hasPrefix(open), line.hasSuffix(close) else { return nil }
    return String(line.dropFirst(open.count).dropLast(close.count))
  }

  for line in contents.split(separator: "\n") {
    if line == "<entry>" {
      entry = JMdictEntry()
    } else if line == "</entry>" {
      entries.append(entry)
    } else if let keb = text(of: line, tag: "keb") {
      entry.kanji.append((keb, false))
    } else if let reb = text(of: line, tag: "reb") {
      entry.readings.append((reb, false))
    } else if let pri = text(of: line, tag: "ke_pri"), commonPriorities.contains(pri) {
      entry.kanji[entry.kanji.count - 1].1 = true
    } else if let pri = text(of: line, tag: "re_pri"), commonPriorities.contains(pri) {
      entry.readings[entry.readings.count - 1].1 = true
    }
  }
  return entries
}

struct JMdictIndex {
  private var entriesByKanji = [String: [JMdictEntry]]()
  private var entriesByReading = [String: [JMdictEntry]]()

  init(_ entries: [JMdictEntry]) {
    for entry in entries {
      for (kanji, _) in entry.kanji {
        entriesByKanji[kanji, default: []].append(entry)
      }
      for (reading, _) in entry.readings {
        entriesByReading[reading, default: []].append(entry)
      }
    }
  }

  // Returns whether the word with these characters and readings is marked common in JMdict.
  func isCommon(japanese: String, readings: [String]) -> Bool {
    if let entries = entriesByKanji[japanese] {
      // Prefer entries that also have one of the readings, since different words can share the
      // same kanji spelling.
      let matching = entries.filter { $0.readings.contains { readings.contains($0.0) } }
      return (matching.isEmpty ? entries : matching).contains { entry in
        entry.kanji.contains { $0 == (japanese, true) }
      }
    }
    // Kana-only vocabulary.
    return entriesByReading[japanese]?.contains { entry in
      entry.readings.contains { $0 == (japanese, true) }
    } ?? false
  }
}

// MARK: - jiten.moe

struct JitenIndex {
  private var rankByWordAndReading = [String: Int]()
  private var rankByWord = [String: Int]()

  init(_ file: URL) {
    let contents = try! String(contentsOf: file, encoding: .utf8)
    // The file has \r\n line endings, which Swift treats as a single Character.
    for line in contents.split(whereSeparator: \.isNewline).dropFirst() { // Skip the header row.
      let columns = line.split(separator: ",")
      guard columns.count == 3, let rank = Int(columns[2]) else { continue }
      let word = String(columns[0]), reading = String(columns[1])
      // Some words appear more than once - keep the most common.
      rankByWordAndReading["\(word)|\(reading)"] =
        min(rank, rankByWordAndReading["\(word)|\(reading)"] ?? .max)
      rankByWord[word] = min(rank, rankByWord[word] ?? .max)
    }
  }

  // Returns the rank of the word with these characters and readings, or nil if it's not in the
  // list.
  func rank(japanese: String, readings: [String]) -> Int? {
    let ranks = readings.compactMap { rankByWordAndReading["\(japanese)|\($0)"] }
    if let rank = ranks.min() {
      return rank
    }
    return rankByWord[japanese]
  }
}

// MARK: - wordfreq

// wordfreq's data file is a gzipped msgpack array. The first element is a header, and each element
// after that is an array of the words that share a frequency, most frequent first. This decodes
// just
// the msgpack types that appear in it.
struct MsgpackReader {
  let bytes: [UInt8]
  var offset = 0

  init(_ bytes: [UInt8]) {
    self.bytes = bytes
  }

  private mutating func take(_ count: Int) -> ArraySlice<UInt8> {
    defer { offset += count }
    return bytes[offset ..< offset + count]
  }

  private mutating func bigEndian(_ count: Int) -> Int {
    take(count).reduce(0) { $0 << 8 | Int($1) }
  }

  enum Value {
    case string(String)
    case array([Value])
    case other
  }

  mutating func read() -> Value {
    let byte = bytes[offset]
    offset += 1
    switch byte {
    case 0x00 ... 0x7F, 0xC2, 0xC3, 0xE0 ... 0xFF: // Small integers and booleans.
      return .other
    case 0xCC: offset += 1
      return .other
    case 0xCD: offset += 2
      return .other
    case 0x80 ... 0x8F: // Small maps.
      for _ in 0 ..< Int(byte & 0x0F) * 2 { _ = read() }
      return .other
    case 0x90 ... 0x9F: return readArray(Int(byte & 0x0F))
    case 0xDC: return readArray(bigEndian(2))
    case 0xDD: return readArray(bigEndian(4))
    case 0xA0 ... 0xBF: return readString(Int(byte & 0x1F))
    case 0xD9: return readString(bigEndian(1))
    case 0xDA: return readString(bigEndian(2))
    default: fail("Unsupported msgpack type 0x\(String(byte, radix: 16))")
    }
  }

  private mutating func readArray(_ count: Int) -> Value {
    .array((0 ..< count).map { _ in read() })
  }

  private mutating func readString(_ count: Int) -> Value {
    .string(String(decoding: take(count), as: UTF8.self))
  }
}

func readWordfreq(_ file: URL) -> [String: Int] {
  var reader = MsgpackReader(Array(try! Data(contentsOf: file)))
  guard case let .array(buckets) = reader.read() else {
    fail("Unexpected wordfreq data in \(file.path)")
  }
  var ret = [String: Int]()
  for case let .array(words) in buckets.dropFirst() { // Skip the header.
    for case let .string(word) in words where ret[word] == nil {
      ret[word] = ret.count + 1
    }
  }
  return ret
}

// MARK: - Main

guard CommandLine.arguments.count == 2 else {
  fail("Usage: swift word_frequency/generate.swift path/to/local-cache.db")
}

let vocabulary = readVocabulary(databasePath: CommandLine.arguments[1])
if vocabulary.isEmpty {
  fail("No vocabulary subjects found in \(CommandLine.arguments[1])")
}

let jmdict = JMdictIndex(readJMdict(cachedFile("JMdict_e", from: jmdictURL, gunzip: true)))
let jitenGlobal = JitenIndex(cachedFile("jiten_freq_global.csv", from: jitenGlobalURL))
let jitenNonFiction =
  JitenIndex(cachedFile("jiten_freq_nonfiction.csv", from: jitenNonFictionURL))
let wordfreq = readWordfreq(cachedFile("large_ja.msgpack", from: wordfreqURL, gunzip: true))

// Each source's rank for a word. wordfreq has no readings, so it's looked up by characters alone.
let rankSources: [(String, [String]) -> Int?] = [
  { jitenGlobal.rank(japanese: $0, readings: $1) },
  { jitenNonFiction.rank(japanese: $0, readings: $1) },
  { japanese, _ in wordfreq[japanese] },
]

// Returns the geometric mean of the word's ranks in the sources that have it, or nil if none do.
func combinedRank(japanese: String, readings: [String]) -> Int? {
  let ranks = rankSources.compactMap { source -> Int? in
    if let rank = source(japanese, readings) {
      return rank
    }
    // The dictionaries list suru verbs like 勉強する without the する, so look up the noun instead.
    guard japanese.count > 2, japanese.hasSuffix("する") else { return nil }
    return source(String(japanese.dropLast(2)),
                  readings.map { $0.hasSuffix("する") ? String($0.dropLast(2)) : $0 })
  }
  if ranks.isEmpty {
    return nil
  }
  let meanLog = ranks.map { log(Double($0)) }.reduce(0, +) / Double(ranks.count)
  return Int(exp(meanLog).rounded())
}

var lines = [String]()
var commonCount = 0, rankCount = 0
for vocab in vocabulary {
  // WaniKani writes affixes like 〜人 with a wave dash, which the dictionaries don't have.
  let japanese = vocab.japanese.replacingOccurrences(of: "〜", with: "")
  var readings = vocab.primaryReadings.map { $0.replacingOccurrences(of: "〜", with: "") }
  // Kana-only vocabulary has no readings - the characters are the reading.
  if readings.isEmpty {
    readings = [japanese]
  }

  var common = jmdict.isCommon(japanese: japanese, readings: readings)
  if !common, japanese.count > 2, japanese.hasSuffix("する") {
    common = jmdict.isCommon(japanese: String(japanese.dropLast(2)),
                             readings: readings.map {
                               $0.hasSuffix("する") ? String($0.dropLast(2)) : $0
                             })
  }
  let rank = combinedRank(japanese: japanese, readings: readings)

  if common {
    commonCount += 1
  }
  if rank != nil {
    rankCount += 1
  }
  // Each entry is "subject ID": [rank, common], where a rank of 0 means it's not known, and
  // common is 1 or 0. This is much smaller than an object with named fields. One entry per line
  // keeps diffs readable.
  if common || rank != nil {
    lines.append("\"\(vocab.id)\":[\(rank ?? 0),\(common ? 1 : 0)]")
  }
}

let json = "{\n" + lines.joined(separator: ",\n") + "\n}\n"
try! json.write(to: outputFile, atomically: true, encoding: .utf8)

print("Wrote \(outputFile.path)")
print("\(vocabulary.count) vocabulary, \(commonCount) common, \(rankCount) with a rank")
