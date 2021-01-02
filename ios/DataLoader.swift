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

@objc
protocol DataLoaderProtocol {
  func levelOf(subjectID id: Int) -> Int

  @objc(isValidSubjectID:)
  func isValid(subjectID id: Int) -> Bool
}

@objcMembers
class DataLoader: NSObject, DataLoaderProtocol {
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

  var deletedSubjectIDs: GPBInt32Array {
    header.deletedSubjectIdsArray
  }
}
