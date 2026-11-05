// Copyright David Sansome
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
import UIKit

// A short-lived ink pill at the bottom of a view that says what just happened and offers to undo
// it, for changes that are easy to make by accident.
class UndoBanner: UIView {
  private static let visibleDuration: TimeInterval = 5

  private let label = UILabel()
  private let undoButton = UIButton(type: .system)
  private var undoHandler: (() -> Void)?
  private var dismissWorkItem: DispatchWorkItem?

  // Shows a banner at the bottom of the view's safe area, replacing any banner already there.
  @discardableResult
  static func show(in view: UIView, message: String,
                   undo: @escaping () -> Void) -> UndoBanner {
    for case let existing as UndoBanner in view.subviews {
      existing.dismiss(animated: false)
    }

    let banner = UndoBanner(message: message, undo: undo)
    banner.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(banner)
    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      banner.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
      banner.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
      banner.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 16),
      banner.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),
      banner.widthAnchor.constraint(lessThanOrEqualToConstant: 500),
    ])

    banner.alpha = 0
    banner.transform = CGAffineTransform(translationX: 0, y: 12)
    UIView.animate(withDuration: 0.25) {
      banner.alpha = 1
      banner.transform = .identity
    }
    UIAccessibility.post(notification: .announcement, argument: message)
    banner.scheduleDismiss()
    return banner
  }

  private init(message: String, undo: @escaping () -> Void) {
    undoHandler = undo
    super.init(frame: .zero)

    backgroundColor = TKMStyle.Color.label
    layer.cornerRadius = 22
    layer.cornerCurve = .continuous
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.18
    layer.shadowRadius = 12
    layer.shadowOffset = CGSize(width: 0, height: 4)

    label.text = message
    label.textColor = TKMStyle.Color.background
    label.font = UIFont.preferredFont(forTextStyle: .subheadline)
    label.adjustsFontForContentSizeCategory = true
    // Messages are short, so keep them on one line and let the banner grow to fit.
    label.numberOfLines = 1
    label.lineBreakMode = .byTruncatingMiddle

    var config = UIButton.Configuration.plain()
    config.attributedTitle = AttributedString("Undo", attributes: AttributeContainer([
      .font: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                               weight: .bold),
    ]))
    config.baseForegroundColor = TKMStyle.Color.background
    config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    undoButton.configuration = config
    undoButton.setContentHuggingPriority(.required, for: .horizontal)
    undoButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    undoButton.addAction(for: .touchUpInside) { [weak self] in self?.undoTapped() }

    let stack = UIStackView(arrangedSubviews: [label, undoButton])
    stack.alignment = .center
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])

    accessibilityElements = [label, undoButton]
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func scheduleDismiss() {
    // Leave it up for longer when VoiceOver needs time to reach the button.
    let duration = UIAccessibility.isVoiceOverRunning ? UndoBanner.visibleDuration * 2 :
      UndoBanner.visibleDuration
    let workItem = DispatchWorkItem { [weak self] in self?.dismiss(animated: true) }
    dismissWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
  }

  private func undoTapped() {
    let handler = undoHandler
    undoHandler = nil
    handler?()
    dismiss(animated: true)
  }

  func dismiss(animated: Bool) {
    dismissWorkItem?.cancel()
    dismissWorkItem = nil
    guard animated else {
      removeFromSuperview()
      return
    }
    UIView.animate(withDuration: 0.2, animations: {
      self.alpha = 0
      self.transform = CGAffineTransform(translationX: 0, y: 12)
    }, completion: { _ in
      self.removeFromSuperview()
    })
  }
}
