// Copyright 2024 David Sansome
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
import WaniKaniAPI

func render(formattedText: [TKMFormattedText],
            standardAttributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
  let text = NSMutableAttributedString()
  for part in formattedText {
    text.append(render(formattedText: part, standardAttributes: standardAttributes))
  }
  return text
}

private func render(formattedText: TKMFormattedText,
                    standardAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
  var attributes = standardAttributes
  for format in formattedText.format {
    switch format {
    case .kanji:
      attributes[.foregroundColor] = TKMStyle.Color.markupKanjiForeground
      attributes[.backgroundColor] = TKMStyle.Color.markupKanjiBackground
    case .vocabulary:
      attributes[.foregroundColor] = TKMStyle.Color.markupVocabularyForeground
      attributes[.backgroundColor] = TKMStyle.Color.markupVocabularyBackground
    case .radical:
      attributes[.foregroundColor] = TKMStyle.Color.markupRadicalForeground
      attributes[.backgroundColor] = TKMStyle.Color.markupRadicalBackground
    case .reading:
      attributes[.foregroundColor] = TKMStyle.Color.background
      attributes[.backgroundColor] = TKMStyle.Color.grey33
    case .bold:
      attributes[.font] = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
    case .italic:
      attributes[.font] = UIFont.italicSystemFont(ofSize: UIFont.systemFontSize)
    case .link:
      attributes[.link] = formattedText.linkURL
    case .apprentice:
      attributes[.foregroundColor] = UIColor.white
      attributes[.backgroundColor] = TKMStyle.color(forSRSStageCategory: .apprentice)
    case .guru:
      attributes[.foregroundColor] = UIColor.white
      attributes[.backgroundColor] = TKMStyle.color(forSRSStageCategory: .guru)
    case .master:
      attributes[.foregroundColor] = UIColor.white
      attributes[.backgroundColor] = TKMStyle.color(forSRSStageCategory: .master)
    case .enlightened:
      attributes[.foregroundColor] = UIColor.white
      attributes[.backgroundColor] = TKMStyle.color(forSRSStageCategory: .enlightened)
    default:
      break
    }
  }
  return NSAttributedString(string: formattedText.text, attributes: attributes)
}
