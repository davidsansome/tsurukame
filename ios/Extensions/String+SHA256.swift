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

// https://stackoverflow.com/a/38788437/3938401

import CommonCrypto
import Foundation

extension Data {
  public func sha256() -> String {
    hexStringFromData(input: digest(input: self as NSData))
  }

  private func digest(input: NSData) -> NSData {
    let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_SHA256(input.bytes, UInt32(input.length), &hash)
    return NSData(bytes: hash, length: digestLength)
  }

  private func hexStringFromData(input: NSData) -> String {
    var bytes = [UInt8](repeating: 0, count: input.length)
    input.getBytes(&bytes, length: input.length)

    var hexString = ""
    for byte in bytes {
      hexString += String(format: "%02x", UInt8(byte))
    }

    return hexString
  }
}

public extension String {
  func sha256() -> String {
    if let stringData = data(using: String.Encoding.utf8) {
      return stringData.sha256()
    }
    return ""
  }
}
