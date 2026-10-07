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
import PromiseKit
import WaniKaniAPI

extension Notification.Name {
  static let logout = Notification.Name("kLogoutNotification")
}

private let kPrivacyPolicyURL = "https://github.com/davidsansome/tsurukame/wiki/Privacy-Policy"

protocol LoginViewControllerDelegate: AnyObject {
  func loginComplete()
}

// Colours for the form on the night background.
private let kFieldColor = UIColor(red: 0.059, green: 0.094, blue: 0.165, alpha: 1)
private let kFieldBorderColor = UIColor(red: 0.227, green: 0.290, blue: 0.420, alpha: 1)
private let kSecondaryOnNight = UIColor(red: 0.620, green: 0.651, blue: 0.722, alpha: 1)

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
  @IBOutlet private var createApiTokenButton: UIButton!
  @IBOutlet private var swapLoginMethodsButton: UIButton!
  @IBOutlet private var privacyPolicyLabel: UILabel!
  @IBOutlet private var privacyPolicyButton: UIButton!
  @IBOutlet private var activityIndicatorOverlay: UIView!
  @IBOutlet private var activityIndicator: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()

    // The sign-in screen is always the night sea, whatever the system appearance.
    overrideUserInterfaceStyle = .dark
    styleForNight()

    if let forcedEmail = forcedEmail {
      emailField.text = forcedEmail
      emailField.isEnabled = false
    }

    if !FeatureFlags.showUsernamePasswordLogin {
      swapLoginMethodsButton.isHidden = true
      privacyPolicyLabel.isHidden = true
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
    signInButton.backgroundColor = enabled ? TKMStyle.Color.accent : kFieldBorderColor
  }

  // MARK: - Appearance

  private func styleForNight() {
    view.backgroundColor = TKMStyle.Color.night

    // The seal and the app's name above the form.
    let hanko = HankoView()
    hanko.transform = CGAffineTransform(rotationAngle: -3 * .pi / 180)
    hanko.layer.shadowColor = UIColor.black.cgColor
    hanko.layer.shadowOpacity = 0.35
    hanko.layer.shadowRadius = 14
    hanko.layer.shadowOffset = CGSize(width: 0, height: 10)
    let title = UILabel()
    title.text = "Tsurukame"
    title.font = UIFont.systemFont(ofSize: 34, weight: .heavy)
    title.textColor = TKMStyle.Color.onNight
    title.accessibilityTraits = .header

    // The sea along the bottom.
    let waves = WavesView()
    waves.fillColor = UIColor(red: 0.133, green: 0.192, blue: 0.310, alpha: 1)
    waves.waveColor = UIColor(red: 0.200, green: 0.278, blue: 0.424, alpha: 1)
    waves.radius = 32

    for v in [waves, hanko, title] {
      v.translatesAutoresizingMaskIntoConstraints = false
    }
    view.insertSubview(waves, at: 0)
    view.addSubview(hanko)
    view.addSubview(title)
    NSLayoutConstraint.activate([
      waves.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      waves.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      waves.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      waves.heightAnchor.constraint(equalToConstant: 150),

      title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      title.bottomAnchor.constraint(equalTo: signInLabel.topAnchor, constant: -10),
      hanko.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      hanko.bottomAnchor.constraint(equalTo: title.topAnchor, constant: -24),
      hanko.widthAnchor.constraint(equalToConstant: 96),
      hanko.heightAnchor.constraint(equalTo: hanko.widthAnchor,
                                    multiplier: HankoView.aspectRatio),
      hanko.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,
                                 constant: 8),
    ])

    // The storyboard's text shadows were for legibility over the old photo background.
    for label in [signInLabel!, privacyPolicyLabel!] {
      label.shadowColor = nil
    }
    for button in [signInButton!, pasteButton!, createApiTokenButton!, swapLoginMethodsButton!,
                   privacyPolicyButton!] {
      button.titleLabel?.shadowColor = nil
      button.setTitleShadowColor(nil, for: .normal)
      button.setTitleShadowColor(nil, for: .disabled)
    }

    signInLabel.textColor = TKMStyle.Color.onNightSecondary
    signInLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    privacyPolicyLabel.textColor = kSecondaryOnNight

    for field in [emailField!, passwordField!, apiTokenField!] {
      field.borderStyle = .none
      field.backgroundColor = kFieldColor
      field.textColor = TKMStyle.Color.onNight
      field.layer.cornerRadius = 14
      field.layer.cornerCurve = .continuous
      field.layer.borderWidth = 1
      field.layer.borderColor = kFieldBorderColor.cgColor
      field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
      field.leftViewMode = .always
      field.attributedPlaceholder = NSAttributedString(string: field.placeholder ?? "",
                                                       attributes: [
                                                         .foregroundColor: kSecondaryOnNight,
                                                       ])
    }

    signInButton.layer.cornerRadius = 14
    signInButton.layer.cornerCurve = .continuous
    signInButton.setTitleColor(.white, for: .normal)
    signInButton.setTitleColor(kSecondaryOnNight, for: .disabled)
    signInButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)

    for button in [pasteButton!, createApiTokenButton!, swapLoginMethodsButton!,
                   privacyPolicyButton!] {
      button.tintColor = TKMStyle.Color.onNight
      button.setTitleColor(TKMStyle.Color.onNight, for: .normal)
    }
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
        Settings.userApiToken = result.apiToken
        Settings.userEmailAddress = self.emailField.text!

        self.delegate?.loginComplete()
      }.catch { error in
        if let wkError = error as? WaniKaniAPI.WaniKaniWebClientError,
           wkError == .accountHibernating {
          self.showHibernatingError()
        } else {
          self.showLoginError(error.localizedDescription)
        }
      }
    } else {
      let token = apiTokenField.text!
      let apiClient = WaniKaniAPIClient(apiToken: token)
      let promise = apiClient.user(progress: Progress())
      promise.done { user in
        NSLog("Login success! User is at level: \(user.currentLevel)")
        Settings.userApiToken = token
        Settings.userEmailAddress = ""
        self.delegate?.loginComplete()
      }.catch { err in
        if let wkError = err as? WaniKaniAPIError,
           wkError.message?.contains("hibernating") ?? false {
          self.showHibernatingError()
        } else {
          self.showLoginError("Unable to login with API token! (\(err.localizedDescription))")
        }
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
                     self.createApiTokenButton.isHidden = animatingInUserPass

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

  @IBAction func didTapCreateApiTokenButton(_: Any) {
    UIApplication.shared
      .open(URL(string: "https://www.wanikani.com/settings/personal_access_tokens")!)
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

  func showHibernatingError() {
    present(CommonErrors.getHibernatingAccountAlertController(), animated: true,
            completion: nil)
    showActivityIndicatorOverlay(false)
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
