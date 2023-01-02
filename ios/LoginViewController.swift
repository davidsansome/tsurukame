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
  var forcedUsername: String?

  @IBOutlet private var signInLabel: UILabel!
  @IBOutlet private var usernameField: UITextField!
  @IBOutlet private var passwordField: UITextField!
  @IBOutlet private var signInButton: UIButton!
  @IBOutlet private var apiKeyField: UITextField!
  @IBOutlet private var signInWithAPIKeyButton: UIButton!
  @IBOutlet private var privacyPolicyLabel: UILabel!
  @IBOutlet private var privacyPolicyButton: UIButton!
  @IBOutlet private var activityIndicatorOverlay: UIView!
  @IBOutlet private var activityIndicator: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()

    TKMStyle.addShadowToView(signInLabel, offset: 0, opacity: 1, radius: 5)
    TKMStyle.addShadowToView(privacyPolicyLabel, offset: 0, opacity: 1, radius: 2)
    TKMStyle.addShadowToView(privacyPolicyButton, offset: 0, opacity: 1, radius: 2)

    if let forcedUsername = forcedUsername {
      usernameField.text = forcedUsername
      usernameField.isEnabled = false
    }

    usernameField.delegate = self
    passwordField.delegate = self
    apiKeyField.delegate = self

    usernameField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    passwordField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    apiKeyField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    textFieldDidChange(usernameField)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  // MARK: - UITextFieldDelegate

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField == usernameField {
      passwordField.becomeFirstResponder()
    } else if textField == passwordField {
      didTapSignInButton()
    } else if textField == apiKeyField {
      didTapSignInWithAPIButton()
    }
    return true
  }

  @objc func textFieldDidChange(_: UITextField) {
    let enabled = !(usernameField.text?.isEmpty ?? false) && !(passwordField.text?.isEmpty ?? false)
    signInButton.isEnabled = enabled
    signInButton.backgroundColor = enabled ? TKMStyle.radicalColor2 : TKMStyle.Color.grey33

    let apiKeyEnabled = !(apiKeyField.text?.isEmpty ?? false)
    signInWithAPIKeyButton.isEnabled = apiKeyEnabled
    signInWithAPIKeyButton.backgroundColor = apiKeyEnabled ? TKMStyle.radicalColor2 : TKMStyle.Color
      .grey33
  }

  // MARK: - Sign In flow

  @IBAction func didTapSignInButton() {
    if !signInButton.isEnabled {
      return
    }
    showActivityIndicatorOverlay(true)

    let client = WaniKaniWebClient()
    let promise = client.login(username: usernameField.text!, password: passwordField.text!)
    promise.done { result in
      NSLog("Login success!")
      Settings.userCookie = result.cookie
      Settings.userApiToken = result.apiToken
      Settings.userEmailAddress = result.emailAddress

      self.delegate?.loginComplete()
    }.catch { error in
      self.showLoginError(error.localizedDescription)
    }
  }

  @IBAction func didTapSignInWithAPIButton() {
    if !signInWithAPIKeyButton.isEnabled {
      return
    }
    showActivityIndicatorOverlay(true)

    let token = apiKeyField.text!
    let apiClient = WaniKaniAPIClient(apiToken: token)
    let progress = Progress()
    let promise = apiClient.user(progress: progress)
    promise.done { user in
      NSLog("Login success! User is at level: \(user.currentLevel)")
      Settings.userCookie = "apiFieldCookie" // dummy cookie since we use the API
      Settings.userApiToken = token
      Settings.userEmailAddress = ""
      self.delegate?.loginComplete()
    }.catch { _ in
      self.showLoginError("Invalid API token!")
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
