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

@objc(TKMAnswerTextField)
class AnswerTextField: UITextField {
  // Returns a Japanese-language UITextInputMode, if available.
  // If this returns nil the user doesn't have a Japanese keyboard installed.
  @objc public class var japaneseTextInputMode: UITextInputMode? {
    for textInputMode in UITextInputMode.activeInputModes {
      if let primaryLanguage = textInputMode.primaryLanguage,
         primaryLanguage.starts(with: "ja") {
        return textInputMode
      }
    }
    return nil
  }

  // Whether to show a Japanese-language keyboard for this text input.
  public var useJapaneseKeyboard: Bool = false {
    didSet {
      if oldValue != useJapaneseKeyboard {
        if self.isFirstResponder {
          // Reload the keyboard if we just changed its language.
          self.resignFirstResponder()
          self.becomeFirstResponder()
        }
      }
    }
  }

  // MARK: - UIResponder

  override var textInputContextIdentifier: String? {
    if useJapaneseKeyboard {
      return "com.tsurukame.answer.ja"
    }
    return "com.tsurukame.answer"
  }

  override var textInputMode: UITextInputMode? {
    if useJapaneseKeyboard, let mode = AnswerTextField.japaneseTextInputMode {
      return mode
    }
    return super.textInputMode
  }
}
