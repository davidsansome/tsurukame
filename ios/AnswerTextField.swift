// Copyright 2020 David Sansome
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

class AnswerTextField: UITextField {
  public var answerLanguage: String? {
    didSet {
      if oldValue != answerLanguage {
        DispatchQueue.main.async {
          if self.isFirstResponder {
            // re-read the language state
            self.resignFirstResponder()
            self.becomeFirstResponder()
          }
        }
      }
    }
  }

  override var textInputContextIdentifier: String? {
    "com.tsurukame.answer"
  }

  private func getKeyboardLanguage() -> String? {
    if Settings.autoSwitchKeyboard {
      return answerLanguage
    }
    return nil
  }

  override var textInputMode: UITextInputMode? {
    if let language = getKeyboardLanguage() {
      for textInputMode in UITextInputMode.activeInputModes {
        if let primaryLanguage = textInputMode.primaryLanguage,
          primaryLanguage.starts(with: language) {
          return textInputMode
        }
      }
    }
    return super.textInputMode
  }
}
