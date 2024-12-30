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
import PromiseKit
import WaniKaniAPI

extension Notification.Name {
  static let logout = Notification.Name("kLogoutNotification")
}

private let kPrivacyPolicyURL = "https://github.com/davidsansome/tsurukame/wiki/Privacy-Policy"

protocol LoginViewControllerDelegate: AnyObject {
  func loginComplete()
}

class LoginViewController: UIViewController, UITextFieldDelegate {
  weak var delegate: LoginViewControllerDelegate?
  var forcedEmail: String?

  @IBOutlet private var signInLabel: UILabel!
  @IBOutlet private var emailField: UITextField!
  @IBOutlet private var passwordField: UITextField!
  @IBOutlet private var signInButton: UIButton!
  @IBOutlet private var apiTokenStack: UIStackView!
  @IBOutlet private var apiTokenField: UITextField!
  @IBOutlet private var pasteButton: UIButton!
  @IBOutlet private var swapLoginMethodsButton: UIButton!
  @IBOutlet private var privacyPolicyLabel: UILabel!
  @IBOutlet private var privacyPolicyButton: UIButton!
  @IBOutlet private var activityIndicatorOverlay: UIView!
  @IBOutlet private var activityIndicator: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()

    if #available(iOS 13.0, *) {
      overrideUserInterfaceStyle = .light
    }

    TKMStyle.addShadowToView(signInLabel, offset: 0, opacity: 1, radius: 5)
    TKMStyle.addShadowToView(privacyPolicyLabel, offset: 0, opacity: 1, radius: 2)
    TKMStyle.addShadowToView(privacyPolicyButton, offset: 0, opacity: 1, radius: 2)
    TKMStyle.addShadowToView(swapLoginMethodsButton, offset: 0, opacity: 1, radius: 2)
    TKMStyle.addShadowToView(pasteButton, offset: 0, opacity: 1, radius: 5)

    if let forcedEmail = forcedEmail {
      emailField.text = forcedEmail
      emailField.isEnabled = false
    }

    emailField.delegate = self
    passwordField.delegate = self
    apiTokenField.delegate = self

    emailField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    passwordField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    apiTokenField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    textFieldDidChange(emailField)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  // MARK: - UITextFieldDelegate

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField == emailField {
      passwordField.becomeFirstResponder()
    } else if textField == passwordField || textField == apiTokenField {
      didTapSignInButton()
    }
    return true
  }

  @objc func textFieldDidChange(_: UITextField) {
    updateSignInButtonState()
  }

  private func updateSignInButtonState() {
    var enabled = false
    if emailField.isHidden {
      enabled = !(apiTokenField.text?.isEmpty ?? true)
    } else {
      enabled = !(emailField.text?.isEmpty ?? true) && !(passwordField.text?.isEmpty ?? true)
    }
    signInButton.isEnabled = enabled
    signInButton.backgroundColor = enabled ? TKMStyle.radicalColor2 : TKMStyle.Color.grey33
  }

  // MARK: - Sign In flow

  @IBAction func didTapSignInButton() {
    if !signInButton.isEnabled {
      return
    }
    showActivityIndicatorOverlay(true)

    if !emailField.isHidden {
      let client = WaniKaniWebClient()
      let promise = client.login(email: emailField.text!, password: passwordField.text!)
      promise.done { result in
        NSLog("Login success!")
        Settings.userCookie = result.cookie
        Settings.userApiToken = result.apiToken
        Settings.userEmailAddress = self.emailField.text!

        self.delegate?.loginComplete()
      }.catch { error in
        self.showLoginError(error.localizedDescription)
      }
    } else {
      let token = apiTokenField.text!
      let apiClient = WaniKaniAPIClient(apiToken: token)
      let promise = apiClient.user(progress: Progress())
      promise.done { user in
        NSLog("Login success! User is at level: \(user.currentLevel)")
        Settings.userCookie = ""
        Settings.userApiToken = token
        Settings.userEmailAddress = ""
        self.delegate?.loginComplete()
      }.catch { err in
        self.showLoginError("Unable to login with API token! (\(err.localizedDescription))")
      }
    }
  }

  @IBAction func didTapSwapLoginMethods() {
    UIView.animate(withDuration: 0.1,
                   delay: 0.0,
                   options: [.curveLinear],
                   animations: {
                     let animatingInUserPass = self.emailField.isHidden
                     self.emailField.isHidden = !animatingInUserPass
                     self.passwordField.isHidden = !animatingInUserPass

                     self.apiTokenStack.isHidden = animatingInUserPass

                     self.emailField.alpha = animatingInUserPass ? 1 : 0
                     self.passwordField.alpha = animatingInUserPass ? 1 : 0
                     self.apiTokenStack.alpha = animatingInUserPass ? 0 : 1
                   }) { _ in
      let title = self.emailField.isHidden ? "Use email and password" : "Use API token"
      self.swapLoginMethodsButton.setTitle(title, for: .normal)
      self.updateSignInButtonState()
    }
  }

  @IBAction func didTapPasteButton(_: Any) {
    if let text = UIPasteboard.general.string {
      apiTokenField.text = text
      updateSignInButtonState()
    }
  }

  // MARK: - Errors and competion

  func showLoginError(_ message: String) {
    DispatchQueue.main.async {
      let c = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
      c.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
      self.present(c, animated: true, completion: nil)
      self.showActivityIndicatorOverlay(false)
    }
  }

  func showActivityIndicatorOverlay(_ visible: Bool) {
    view.endEditing(true)
    activityIndicatorOverlay.isHidden = !visible
    activityIndicator.isHidden = !visible
    if visible {
      activityIndicator.startAnimating()
    } else {
      activityIndicator.stopAnimating()
    }
  }

  // MARK: - Privacy policy

  @IBAction func didTapPrivacyPolicyButton() {
    let url = URL(string: kPrivacyPolicyURL)!
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
}
