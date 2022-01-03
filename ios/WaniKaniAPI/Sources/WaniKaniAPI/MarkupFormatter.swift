// Copyright 2022 David Sansome
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

private let kTagRE =
  try! NSRegularExpression(pattern: #"([^\[<]*)"# +
    #"(?:[\[<]"# +
    #"(/?(?:vocabulary|reading|ja|jp|kanji|radical|b|em|i|strong|kan|a))"# +
    #"(?: href="([^"]+)"[^>]*)?"# +
    #"[\]>])"#, options: [.caseInsensitive])

public func parseFormattedText(_ text: String?) -> [TKMFormattedText] {
  var ret = [TKMFormattedText]()
  guard let text = text else {
    return ret
  }

  var formatStack = [TKMFormattedText.Format]()
  var linkUrlStack = [String]()
  var lastIndex = 0

  let nsString = text.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
  for result in kTagRE.matches(in: text, options: [], range: NSMakeRange(0, nsString.length)) {
    lastIndex = result.range.upperBound
    let text = nsString.substring(with: result.range(at: 1))
    let nextTag = nsString.substring(with: result.range(at: 2))
    let href = result.range(at: 3).location == NSNotFound ? nil : nsString
      .substring(with: result.range(at: 3))

    if nextTag.isEmpty {
      continue
    }

    // Add this text.
    if !text.isEmpty {
      var formattedText = TKMFormattedText()
      formattedText.text = text
      formattedText.format = formatStack
      if let url = linkUrlStack.last {
        formattedText.linkURL = url
      }
      ret.append(formattedText)
    }

    // Add the next format tag.
    if nextTag.first! == "/" {
      if !formatStack.isEmpty {
        let lastTag = formatStack.removeLast()
        if lastTag == .link {
          linkUrlStack.removeLast()
        }
      }
    } else {
      switch nextTag.lowercased() {
      case "radical":
        formatStack.append(.radical)
      case "ja", "jp":
        formatStack.append(.japanese)
      case "reading":
        formatStack.append(.reading)
      case "vocabulary":
        formatStack.append(.vocabulary)
      case "i":
        formatStack.append(.italic)
      case "kanji", "kan":
        formatStack.append(.kanji)
      case "b", "em", "strong":
        formatStack.append(.bold)
      case "a":
        formatStack.append(.link)
        linkUrlStack.append(href ?? "")
      default:
        NSLog("Unknown formatted text tag: %@", nextTag)
      }
    }
  }

  // Add the leftover text.
  if lastIndex != nsString.length {
    var formattedText = TKMFormattedText()
    formattedText.text = nsString.substring(from: lastIndex)
    formattedText.format = formatStack
    ret.append(formattedText)
  }

  return ret
}
