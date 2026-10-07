// Copyright 2026 David Sansome
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
  // Returns a Japanese-language UITextInputMode, if available.
  // If this returns nil the user doesn't have a Japanese keyboard installed.
  public class var japaneseTextInputMode: UITextInputMode? {
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
        if isFirstResponder {
          // Reload the keyboard if we just changed its language.
          reloadInputViews()
        }
      }
    }
  }

  // MARK: - Appearance

  // The field is drawn as a rounded box inset from the edges of the text field. The review screen
  // marks a wrong answer by colouring its text with the accent colour, and the box follows suit.
  private static let horizontalInset: CGFloat = 16
  private static let verticalInset: CGFloat = 6
  // Room on the right for the submit button that sits over the field.
  private static let trailingTextInset: CGFloat = 56

  private let fieldLayer = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    borderStyle = .none
    fieldLayer.lineWidth = 2
    layer.insertSublayer(fieldLayer, at: 0)
    updateFieldColors()
  }

  // Set when the field sits on ink (the reading prompt), where an ink outline wouldn't show.
  public var isOnInk = false {
    didSet { updateFieldColors() }
  }

  private var isMarkedIncorrect: Bool {
    textColor == TKMStyle.Color.accent
  }

  override var textColor: UIColor? {
    didSet { updateFieldColors() }
  }

  private var fieldRect: CGRect {
    bounds.insetBy(dx: AnswerTextField.horizontalInset, dy: AnswerTextField.verticalInset)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    fieldLayer.frame = bounds
    fieldLayer.path = UIBezierPath(roundedRect: fieldRect, cornerRadius: 18).cgPath
  }

  override func textRect(forBounds bounds: CGRect) -> CGRect {
    bounds.inset(by: UIEdgeInsets(top: 0, left: AnswerTextField.trailingTextInset, bottom: 0,
                                  right: AnswerTextField.trailingTextInset))
  }

  override func editingRect(forBounds bounds: CGRect) -> CGRect {
    textRect(forBounds: bounds)
  }

  override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
    textRect(forBounds: bounds)
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    updateFieldColors()
  }

  private func updateFieldColors() {
    let incorrectFill = UIColor { tc in
      tc.userInterfaceStyle == .dark ?
        UIColor(red: 0.239, green: 0.141, blue: 0.125, alpha: 1) :
        UIColor(red: 0.984, green: 0.906, blue: 0.886, alpha: 1)
    }
    let fill = isMarkedIncorrect ? incorrectFill : TKMStyle.Color.cellBackground
    let stroke = isMarkedIncorrect ? TKMStyle.Color.accent :
      isOnInk ? TKMStyle.Color.onNightSecondary : TKMStyle.Color.label
    fieldLayer.fillColor = fill.resolvedColor(with: traitCollection).cgColor
    fieldLayer.strokeColor = stroke.resolvedColor(with: traitCollection).cgColor
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
