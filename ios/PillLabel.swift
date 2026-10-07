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

import Foundation

// A small translucent white pill for showing facts over a subject's colour, like its level and
// SRS stage.
class PillLabel: UILabel {
  var insets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12) {
    didSet { invalidateIntrinsicContentSize() }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    font = UIFont.systemFont(ofSize: 12, weight: .bold)
    textColor = .white
    backgroundColor = UIColor.white.withAlphaComponent(0.18)
    clipsToBounds = true
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(width: size.width + insets.left + insets.right,
                  height: size.height + insets.top + insets.bottom)
  }

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }
}
