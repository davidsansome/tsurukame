// Copyright 2025 David Sansome
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

import UIKit

struct BottomSheetAction {
  let title: String
  let style: Style
  let handler: (() -> Void)?

  enum Style {
    case `default`
    case destructive
    case cancel
  }

  init(title: String, style: Style = .default, handler: (() -> Void)? = nil) {
    self.title = title
    self.style = style
    self.handler = handler
  }
}

class BottomSheetViewController: UIViewController {
  private let actions: [BottomSheetAction]
  private let sheetTitle: String?
  private let sheetMessage: String?

  private let containerView = UIView()
  private let stackView = UIStackView()
  private let dimmingView = UIView()

  private var containerBottomConstraint: NSLayoutConstraint?

  init(title: String?, message: String?, actions: [BottomSheetAction]) {
    sheetTitle = title
    sheetMessage = message
    self.actions = actions
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    setupDimmingView()
    setupContainerView()
    setupStackView()
    setupActions()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    animateIn()
  }

  private func setupDimmingView() {
    dimmingView.backgroundColor = .clear
    dimmingView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(dimmingView)

    NSLayoutConstraint.activate([
      dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
      dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped))
    dimmingView.addGestureRecognizer(tapGesture)
  }

  private func setupContainerView() {
    if #available(iOS 13.0, *) {
      containerView.backgroundColor = .systemBackground
    } else {
      containerView.backgroundColor = .white
    }
    containerView.layer.cornerRadius = 16
    containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    containerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(containerView)

    containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor,
                                                                      constant: 400)

    NSLayoutConstraint.activate([
      containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      containerBottomConstraint!,
    ])
  }

  private func setupStackView() {
    stackView.axis = .vertical
    stackView.spacing = 0
    stackView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
      stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      stackView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor,
                                        constant: -8),
    ])
  }

  private func setupActions() {
    // Add title if present
    if let title = sheetTitle, !title.isEmpty {
      let titleLabel = UILabel()
      titleLabel.text = title
      titleLabel.font = .boldSystemFont(ofSize: 13)
      if #available(iOS 13.0, *) {
        titleLabel.textColor = .secondaryLabel
      } else {
        titleLabel.textColor = .gray
      }
      titleLabel.textAlignment = .center
      titleLabel.numberOfLines = 0
      stackView.addArrangedSubview(titleLabel)

      let titlePadding = UIView()
      titlePadding.translatesAutoresizingMaskIntoConstraints = false
      titlePadding.heightAnchor.constraint(equalToConstant: 4).isActive = true
      stackView.addArrangedSubview(titlePadding)
    }

    // Add message if present
    if let message = sheetMessage, !message.isEmpty {
      let messageLabel = UILabel()
      messageLabel.text = message
      messageLabel.font = .systemFont(ofSize: 13)
      if #available(iOS 13.0, *) {
        messageLabel.textColor = .secondaryLabel
      } else {
        messageLabel.textColor = .gray
      }
      messageLabel.textAlignment = .center
      messageLabel.numberOfLines = 0
      stackView.addArrangedSubview(messageLabel)

      let messagePadding = UIView()
      messagePadding.translatesAutoresizingMaskIntoConstraints = false
      messagePadding.heightAnchor.constraint(equalToConstant: 16).isActive = true
      stackView.addArrangedSubview(messagePadding)
    }

    // Separate cancel action from others
    let cancelAction = actions.first { $0.style == .cancel }
    let otherActions = actions.filter { $0.style != .cancel }

    // Add non-cancel actions
    for (index, action) in otherActions.enumerated() {
      if index > 0 {
        let separator = createSeparator()
        stackView.addArrangedSubview(separator)
      }
      let button = createButton(for: action)
      stackView.addArrangedSubview(button)
    }

    // Add cancel action at the bottom with extra spacing
    if let cancel = cancelAction {
      let spacer = UIView()
      spacer.translatesAutoresizingMaskIntoConstraints = false
      spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
      if #available(iOS 13.0, *) {
        spacer.backgroundColor = .systemGroupedBackground
      } else {
        spacer.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
      }
      stackView.addArrangedSubview(spacer)

      let button = createButton(for: cancel)
      button.titleLabel?.font = .boldSystemFont(ofSize: 20)
      stackView.addArrangedSubview(button)
    }
  }

  private func createButton(for action: BottomSheetAction) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(action.title, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 20)
    button.contentHorizontalAlignment = .center
    button.translatesAutoresizingMaskIntoConstraints = false
    button.heightAnchor.constraint(equalToConstant: 57).isActive = true

    switch action.style {
    case .default:
      button.setTitleColor(.systemBlue, for: .normal)
    case .destructive:
      button.setTitleColor(.systemRed, for: .normal)
    case .cancel:
      button.setTitleColor(.systemBlue, for: .normal)
    }

    button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
    button.tag = actions.firstIndex(where: { $0.title == action.title }) ?? 0

    return button
  }

  @objc private func buttonTapped(_ sender: UIButton) {
    let action = actions[sender.tag]
    animateOut {
      action.handler?()
    }
  }

  private func createSeparator() -> UIView {
    let separator = UIView()
    if #available(iOS 13.0, *) {
      separator.backgroundColor = .separator
    } else {
      separator.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
    }
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    return separator
  }

  @objc private func dimmingViewTapped() {
    // Find and execute cancel action, or just dismiss
    let cancelAction = actions.first { $0.style == .cancel }
    animateOut {
      cancelAction?.handler?()
    }
  }

  private func animateIn() {
    view.layoutIfNeeded()
    containerBottomConstraint?.constant = 0

    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
      self.view.layoutIfNeeded()
    }
  }

  private func animateOut(completion: (() -> Void)? = nil) {
    containerBottomConstraint?.constant = 400

    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
      self.view.layoutIfNeeded()
    }) { _ in
      self.dismiss(animated: false) {
        completion?()
      }
    }
  }
}
