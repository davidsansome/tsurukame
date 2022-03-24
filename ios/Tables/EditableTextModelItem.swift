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

class EditableTextModelItem: AttributedModelItem {
  let placeholderText: String
  let font: UIFont

  var textChangedCallback: ((_ text: String) -> Void)?

  init(text: NSAttributedString, placeholderText: String, rightButtonImage: UIImage?,
       font: UIFont) {
    self.placeholderText = placeholderText
    self.font = font
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
    placeholderLabel.frame = textView.frame
  }

  override func update(with baseItem: TKMModelItem!) {
    super.update(with: baseItem)
    let item = baseItem as! EditableTextModelItem

    textView.font = item.font
    placeholderLabel.text = item.placeholderText
    placeholderLabel.font = item.font
    placeholderLabel.textColor = TKMStyle.Color.placeholderText

    if item.rightButtonImage != nil {
      textView.isEditable = false
    } else {
      textView.isEditable = true
      textView.becomeFirstResponder()
    }
  }

  override func didTapRightButton() {
    removeRightButton()

    let item = self.item as! EditableTextModelItem
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
}
