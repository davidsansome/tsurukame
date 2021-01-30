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

extension NSMutableAttributedString {
  func replaceFontSize(_ newSize: CGFloat) -> NSMutableAttributedString {
    beginEditing()
    enumerateAttribute(.font, in: NSMakeRange(0, length), options: []) { value, range, _ in
      var font: UIFont
      if value == nil {
        font = UIFont.systemFont(ofSize: newSize)
      } else {
        font = UIFont(descriptor: (value as! UIFont).fontDescriptor, size: newSize)
      }
      removeAttribute(.font, range: range)
      addAttribute(.font, value: font, range: range)
    }
    endEditing()
    return self
  }
}

extension NSAttributedString {
  func string(withFontSize newSize: CGFloat) -> NSAttributedString {
    let ret = NSMutableAttributedString(attributedString: self)
    return ret.replaceFontSize(newSize)
  }
}
