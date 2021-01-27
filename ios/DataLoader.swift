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

import Foundation

private func readUInt32(_ fh: FileHandle, _ offset: UInt64) -> UInt32 {
  fh.seek(toFileOffset: offset)
  let data = fh.readData(ofLength: 4)
  return data.withUnsafeBytes {
    (p: UnsafeRawBufferPointer) in
    p.bindMemory(to: UInt32.self).first!
  }
}

@objcMembers
class DataLoader: NSObject {
  let header: TKMDataFileHeader

  private let file: FileHandle
  private let firstSubjectOffset: UInt32

  public init(fromURL url: URL) throws {
    // Open the file.
    file = try FileHandle(forReadingFrom: url)

    // Read the header.
    let headerLength = readUInt32(file, 0)
    let headerData = file.readData(ofLength: Int(headerLength))
    header = try TKMDataFileHeader(data: headerData)

    // The subjects start after the header.
    firstSubjectOffset = 4 + headerLength
  }

  func levelOf(subjectID id: Int) -> Int {
    if id < 0 || id >= header.levelBySubjectArray.count {
      return 0
    }
    return Int(header.levelBySubjectArray.value(at: UInt(id)))
  }

  @objc(isValidSubjectID:)
  func isValid(subjectID id: Int) -> Bool {
    let level = levelOf(subjectID: id)
    return level > 0 && level <= maxLevelGrantedBySubscription
  }

  @objc(loadSubject:)
  func load(subjectID id: Int) -> TKMSubject? {
    if !isValid(subjectID: id) {
      return nil
    }

    do {
      let offset = firstSubjectOffset + header.subjectByteOffsetArray.value(at: UInt(id))
      file.seek(toFileOffset: UInt64(offset))

      var data: Data
      if id == header.subjectByteOffsetArray.count - 1 {
        data = file.readDataToEndOfFile()
      } else {
        // Read the offset of the next subject and compare to determine the length.
        let nextOffset = firstSubjectOffset + header.subjectByteOffsetArray.value(at: UInt(id + 1))
        let length = nextOffset - offset

        data = file.readData(ofLength: Int(length))
      }

      let ret = try TKMSubject(data: data)
      ret.id_p = Int32(id)
      return ret
    } catch {
      return nil
    }
  }

  var maxSubjectLevel: Int {
    header.subjectsByLevelArray.count
  }

  private var _maxLevelGrantedBySubscription = 60
  var maxLevelGrantedBySubscription: Int {
    get {
      min(_maxLevelGrantedBySubscription, maxSubjectLevel)
    }
    set {
      _maxLevelGrantedBySubscription = newValue
    }
  }

  func loadAll() -> [TKMSubject] {
    var ret = [TKMSubject]()
    for id in 1 ... header.subjectByteOffsetArray.count {
      if let subject = load(subjectID: Int(id)) {
        ret.append(subject)
      }
    }
    return ret
  }

  func subjects(byLevel level: Int) -> TKMSubjectsByLevel? {
    if level <= 0 || level > maxLevelGrantedBySubscription {
      return nil
    }

    return header.subjectsByLevelArray?[level - 1] as? TKMSubjectsByLevel
  }

  var deletedSubjectIDs: GPBInt32Array {
    header.deletedSubjectIdsArray
  }
}
