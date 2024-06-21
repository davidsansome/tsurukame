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

class EditableTextModelItem: AttributedModelItem {
  let placeholderText: String
  let font: UIFont
  let autoCapitalizationType: UITextAutocapitalizationType
  let maximumNumberOfLines: Int

  var textChangedCallback: ((_ text: String) -> Void)?
  var becomeFirstResponderImmediately = true

  init(text: NSAttributedString, placeholderText: String, rightButtonImage: UIImage?,
       font: UIFont, autoCapitalizationType: UITextAutocapitalizationType = .sentences,
       maximumNumberOfLines: Int = 0) {
    self.placeholderText = placeholderText
    self.font = font
    self.autoCapitalizationType = autoCapitalizationType
    self.maximumNumberOfLines = maximumNumberOfLines
    super.init(text: text)

    self.rightButtonImage = rightButtonImage
  }

  override func cellClass() -> AnyClass! {
    EditableTextModelCell.self
  }
}

class EditableTextModelCell: AttributedModelCell, UITextViewDelegate {
  var placeholderLabel: UILabel!

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    placeholderLabel = UILabel(frame: bounds)
    placeholderLabel.isUserInteractionEnabled = false
    addSubview(placeholderLabel)

    textView.delegate = self
  }

  // MARK: - AttributedModelCell

  override func layoutSubviews() {
    super.layoutSubviews()

    placeholderLabel.isHidden = !textView.text.isEmpty

    // Make the placeholder overlap the textView, but use the full height of the cell so it's not
    // clipped.
    placeholderLabel.frame = CGRect(x: textView.frame.minX, y: bounds.minY,
                                    width: textView.frame.width, height: bounds.height)
  }

  override func update(with baseItem: TKMModelItem!) {
    super.update(with: baseItem)
    let item = baseItem as! EditableTextModelItem

    textView.font = item.font
    textView.textColor = TKMStyle.Color.label
    textView.autocapitalizationType = item.autoCapitalizationType
    textView.textContainer.maximumNumberOfLines = item.maximumNumberOfLines
    placeholderLabel.text = item.placeholderText
    placeholderLabel.font = item.font
    placeholderLabel.textColor = TKMStyle.Color.placeholderText

    if item.rightButtonImage != nil {
      textView.isEditable = false
    } else {
      textView.isEditable = true
      if item.becomeFirstResponderImmediately {
        textView.becomeFirstResponder()
      }
    }
  }

  override func didTapRightButton() {
    let item = self.item as! EditableTextModelItem

    if let rightButtonCallback = item.rightButtonCallback {
      rightButtonCallback(self)
      return
    }

    removeRightButton()

    item.rightButtonImage = nil

    // Make the text view editable and start editing.
    textView.isEditable = true
    textView.becomeFirstResponder()
  }

  override func didSelect() {
    if textView.isEditable {
      textView.becomeFirstResponder()
    }
  }

  // MARK: - UITextViewDelegate

  func textViewDidChange(_ textView: UITextView) {
    // Resize the row to match the text view's new size.
    DispatchQueue.main.async { [weak self] in
      self?.tableView?.beginUpdates()
      self?.tableView?.endUpdates()
    }

    let item = self.item as! EditableTextModelItem
    item.text = textView.attributedText
    item.textChangedCallback?(textView.text)
  }

  func textView(_ textView: UITextView, shouldChangeTextIn _: NSRange,
                replacementText text: String) -> Bool {
    // don't allow more lines of text than wanted
    // code edited from https://stackoverflow.com/a/54924572/3938401
    if textView.textContainer.maximumNumberOfLines == 0 {
      return true
    }
    let existingLines = textView.text.components(separatedBy: CharacterSet.newlines)
    let newLines = text.components(separatedBy: CharacterSet.newlines)
    let linesAfterChange = existingLines.count + newLines.count - 1
    return linesAfterChange <= textView.textContainer.maximumNumberOfLines
  }
}
