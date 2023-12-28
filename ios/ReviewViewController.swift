// Copyright 2023 David Sansome
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
import WaniKaniAPI

private let kDefaultAnimationDuration: TimeInterval = 0.25
// Undocumented, but it's what the keyboard animations use.
private let kDefaultAnimationCurve = UIView.AnimationCurve(rawValue: 7)!

private let kPreviousSubjectScale: CGFloat = 0.25
private let kPreviousSubjectButtonPadding: CGFloat = 6.0
private let kPreviousSubjectAnimationDuration: Double = 0.3

private let kReadingTextColor = UIColor.white
private let kMeaningTextColor = UIColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1.0)
private let kDefaultButtonTintColor = UIButton().tintColor

// If the keyboard height changes by less than this amount, the question label will stay where it
// is.
private let kSmallKeyboardHeightChange: CGFloat = 50.0

enum AnswerResult {
  case Correct
  case Incorrect
  case OverrideAnswerCorrect
  case AskAgainLater

  var correct: Bool {
    self == .Correct || self == .OverrideAnswerCorrect
  }
}

private func copyLabel(_ original: UILabel) -> UILabel {
  let copy = UILabel()
  copy.isHidden = original.isHidden
  copy.transform = original.transform
  copy.bounds = original.bounds
  copy.center = original.center
  copy.attributedText = original.attributedText
  copy.font = original.font
  copy.textColor = original.textColor
  copy.textAlignment = original.textAlignment
  original.superview?.addSubview(copy)
  return copy
}

private let kDotColorApprentice = UIColor(red: 0.87, green: 0.00, blue: 0.58, alpha: 1.0)
private let kDotColorGuru = UIColor(red: 0.53, green: 0.18, blue: 0.62, alpha: 1.0)
private let kDotColorMaster = UIColor(red: 0.16, green: 0.30, blue: 0.86, alpha: 1.0)
private let kDotColorEnlightened = UIColor(red: 0.00, green: 0.58, blue: 0.87, alpha: 1.0)
private let kDotColorBurned = UIColor(red: 0.26, green: 0.26, blue: 0.26, alpha: 1.0)

private func getDots(stage: SRSStage) -> NSAttributedString? {
  var string: NSMutableAttributedString?
  switch stage {
  case .apprentice1:
    string = NSMutableAttributedString(string: "•◦◦◦",
                                       attributes: [.foregroundColor: kDotColorApprentice])
  case .apprentice2:
    string = NSMutableAttributedString(string: "••◦◦",
                                       attributes: [.foregroundColor: kDotColorApprentice])
  case .apprentice3:
    string = NSMutableAttributedString(string: "•••◦",
                                       attributes: [.foregroundColor: kDotColorApprentice])
  case .apprentice4:
    string = NSMutableAttributedString(string: "••••◦",
                                       attributes: [.foregroundColor: kDotColorApprentice])
    string?
      .addAttribute(.foregroundColor, value: kDotColorGuru, range: NSRange(location: 4, length: 1))
  case .guru1:
    string = NSMutableAttributedString(string: "•◦", attributes: [.foregroundColor: kDotColorGuru])
  case .guru2:
    string = NSMutableAttributedString(string: "••◦", attributes: [.foregroundColor: kDotColorGuru])
    string?
      .addAttribute(.foregroundColor, value: kDotColorMaster,
                    range: NSRange(location: 2, length: 1))
  case .master:
    string = NSMutableAttributedString(string: "•◦",
                                       attributes: [.foregroundColor: kDotColorMaster])
    string?
      .addAttribute(.foregroundColor, value: kDotColorEnlightened,
                    range: NSRange(location: 1, length: 1))
  case .enlightened:
    string = NSMutableAttributedString(string: "•◦",
                                       attributes: [.foregroundColor: kDotColorEnlightened])
    string?
      .addAttribute(.foregroundColor, value: kDotColorBurned,
                    range: NSRange(location: 1, length: 1))
  case .burned:
    string = NSMutableAttributedString(string: "•", attributes: [.foregroundColor: kDotColorBurned])
  default:
    string = nil
  }
  return string
}

private class AnimationContext {
  let cheats: Bool
  let subjectDetailsViewShown: Bool

  private var fadingLabels = [(UILabel, UILabel)]()

  init(cheats: Bool, subjectDetailsViewShown: Bool) {
    self.cheats = cheats
    self.subjectDetailsViewShown = subjectDetailsViewShown
  }

  func addFadingLabel(original: UILabel) {
    let copy = copyLabel(original)
    original.alpha = 0.0
    fadingLabels.append((original, copy))
  }

  func animateFadingLabels() {
    for (original, copy) in fadingLabels {
      original.alpha = 1.0
      switch original.textAlignment {
      case NSTextAlignment.natural:
        fallthrough
      case NSTextAlignment.left:
        copy.center = CGPoint(x: original.frame.minX + copy.frame.size.width / 2,
                              y: original.frame.minY + copy.frame.size.height / 2)
      default:
        copy.center = original.center
        copy.bounds = original.bounds
      }
      copy.transform = original.transform
      copy.alpha = 0.0
    }
  }

  deinit {
    for (_, copy) in fadingLabels {
      copy.removeFromSuperview()
    }
  }
}

@objc
protocol ReviewViewControllerDelegate: AnyObject {
  func allowsCheats(forReviewItem item: ReviewItem) -> Bool
  func allowsCustomFonts() -> Bool
  func showsSuccessRate() -> Bool
  func finishedAllReviewItems(_ reviewViewController: ReviewViewController)

  @objc optional func tappedMenuButton(reviewViewController: ReviewViewController,
                                       menuButton: UIButton)
}

class ReviewViewController: UIViewController, UITextFieldDelegate, SubjectDelegate {
  private var kanaInput: TKMKanaInput!
  private let hapticGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator
    .FeedbackStyle.light)
  private let tickImage = UIImage(named: "checkmark.circle")
  private let forwardArrowImage = UIImage(named: "ic_arrow_forward_white")
  private let skipImage = UIImage(named: "goforward.plus")

  private var services: TKMServices!
  private var showMenuButton: Bool!
  private var showSubjectHistory: Bool!
  private weak var delegate: ReviewViewControllerDelegate!

  private var session: ReviewSession!

  private var lastMarkAnswerWasFirstTime = false
  private var ankiModeCachedSubmit = false
  private var isAnimatingSubjectDetailsView = false

  private var previousSubjectGradient: CAGradientLayer!

  private var previousSubject: TKMSubject?
  private var previousSubjectLabel: UILabel?

  private var isPracticeSession = false

  // These are set to match the keyboard animation.
  private var animationDuration: Double = kDefaultAnimationDuration
  private var animationCurve: UIView.AnimationCurve = kDefaultAnimationCurve
  private var previousKeyboardInsetHeight: CGFloat?

  private var currentFontName: String!
  private var availableFonts: [String]?
  private var defaultFontSize: Double!

  @IBOutlet private var menuButton: UIButton!
  @IBOutlet private var questionBackground: GradientView!
  @IBOutlet private var promptBackground: GradientView!
  @IBOutlet private var questionLabel: UILabel!
  @IBOutlet private var promptLabel: UILabel!
  @IBOutlet private var answerField: AnswerTextField!
  @IBOutlet private var submitButton: UIButton!
  @IBOutlet private var addSynonymButton: UIButton!
  @IBOutlet private var revealAnswerButton: UIButton!
  @IBOutlet private var progressBar: UIProgressView!
  @IBOutlet private var subjectDetailsView: SubjectDetailsView!
  @IBOutlet private var previousSubjectButton: UIButton!

  @IBOutlet private var wrapUpLabel: UILabel!
  @IBOutlet private var successRateLabel: UILabel!
  @IBOutlet private var doneLabel: UILabel!
  @IBOutlet private var queueLabel: UILabel!
  @IBOutlet private var wrapUpIcon: UIImageView!
  @IBOutlet private var successRateIcon: UIImageView!
  @IBOutlet private var doneIcon: UIImageView!
  @IBOutlet private var queueIcon: UIImageView!
  @IBOutlet private var levelLabel: UILabel!

  @IBOutlet private var answerFieldToBottomConstraint: NSLayoutConstraint!
  @IBOutlet private var answerFieldToSubjectDetailsViewConstraint: NSLayoutConstraint!
  @IBOutlet private var previousSubjectButtonWidthConstraint: NSLayoutConstraint!
  @IBOutlet private var previousSubjectButtonHeightConstraint: NSLayoutConstraint!
  @IBOutlet private var questionLabelBottomConstraint: NSLayoutConstraint!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    kanaInput = TKMKanaInput(delegate: self)
  }

  @objc
  public func setup(services: TKMServices,
                    items: [ReviewItem],
                    showMenuButton: Bool,
                    showSubjectHistory: Bool,
                    delegate: ReviewViewControllerDelegate,
                    isPracticeSession: Bool = false) {
    self.services = services
    self.showMenuButton = showMenuButton
    self.showSubjectHistory = showSubjectHistory
    self.delegate = delegate
    self.isPracticeSession = isPracticeSession

    session = ReviewSession(services: services, items: items,
                            isPracticeSession: isPracticeSession)
  }

  public var activeQueueLength: Int {
    session.activeQueueLength
  }

  public var tasksAnsweredCorrectly: Int {
    session.tasksAnsweredCorrectly
  }

  // MARK: - UIViewController

  private let nd = NotificationDispatcher()

  override func viewDidLoad() {
    super.viewDidLoad()

    TKMStyle.addShadowToView(questionLabel, offset: 1, opacity: 0.2, radius: 4)
    TKMStyle.addShadowToView(previousSubjectButton, offset: 0, opacity: 0.7, radius: 4)

    wrapUpIcon.image = UIImage(named: "baseline_access_time_black_24pt")?
      .withRenderingMode(UIImage.RenderingMode.alwaysTemplate)

    previousSubjectGradient = CAGradientLayer()
    previousSubjectGradient.cornerRadius = 4.0
    previousSubjectButton.layer.addSublayer(previousSubjectGradient)

    nd.add(name: UIResponder.keyboardWillShowNotification) { [weak self] notification in
      self?.keyboardWillShow(notification)
    }
    nd.add(name: UIResponder.keyboardWillHideNotification) { [weak self] _ in
      self?.keyboardWillHide()
    }

    subjectDetailsView.setup(services: services, delegate: self)

    answerField.autocapitalizationType = .none
    answerField.delegate = kanaInput
    answerField.addAction(for: .editingChanged) { [weak self] in self?.answerFieldValueDidChange() }

    let showSuccessRate = delegate.showsSuccessRate()
    successRateIcon.isHidden = !showSuccessRate
    successRateLabel.isHidden = !showSuccessRate

    if !showMenuButton {
      menuButton.isHidden = true
    }

    currentFontName = TKMStyle.japaneseFontName
    defaultFontSize = Double(questionLabel.font.pointSize)

    questionLabel.isUserInteractionEnabled = false

    let shortPressRecognizer =
      UITapGestureRecognizer(target: self, action: #selector(didShortPressQuestionLabel))
    questionBackground.addGestureRecognizer(shortPressRecognizer)

    let leftSwipeRecognizer = UISwipeGestureRecognizer(target: self,
                                                       action: #selector(didSwipeQuestionLabel))
    leftSwipeRecognizer.direction = .left
    questionBackground.addGestureRecognizer(leftSwipeRecognizer)
    let rightSwipeRecognizer = UISwipeGestureRecognizer(target: self,
                                                        action: #selector(didSwipeQuestionLabel))
    rightSwipeRecognizer.direction = .right
    questionBackground.addGestureRecognizer(rightSwipeRecognizer)

    leftSwipeRecognizer.require(toFail: shortPressRecognizer)
    rightSwipeRecognizer.require(toFail: shortPressRecognizer)

    viewDidLayoutSubviews()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    // Fix the extra inset at the top of the subject details view. This isn't necessary after iOS
    // 15.
    if #available(iOS 15.0, *) {} else {
      subjectDetailsView
        .contentInset = UIEdgeInsets(top: -view.tkm_safeAreaInsets.top, left: 0, bottom: 0,
                                     right: 0)
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    if !session.hasStarted {
      // This must be done for the first time after the view has been added
      // to the window, since the window may override the userInterfaceStyle.
      randomTask()
    }

    super.viewWillAppear(animated)
    SiriShortcutHelper.shared
      .attachShortcutActivity(self, type: .reviews)
    navigationController?.setNavigationBarHidden(true, animated: false)
    if subjectDetailsView.isHidden {
      answerField.becomeFirstResponder()
      answerField.reloadInputViews()
    } else {
      subjectDetailsView.becomeFirstResponder()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    subjectDetailsView.deselectLastSubjectChipTapped()
    if subjectDetailsView.isHidden {
      DispatchQueue.main.async {
        self.focusAnswerField()
      }
    }
  }

  @objc public func focusAnswerField() {
    answerField.becomeFirstResponder()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    UIStatusBarStyle.lightContent
  }

  // MARK: - Event handlers

  @objc private func keyboardWillShow(_ notification: Notification) {
    guard let keyboardFrame = notification
      .userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let animationDuration = notification
      .userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
      let animationCurve = notification
      .userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
    else {
      return
    }
    self.animationDuration = animationDuration
    self.animationCurve = UIView.AnimationCurve(rawValue: animationCurve)!

    resizeKeyboard(toHeight: Double(keyboardFrame.size.height))
  }

  private func keyboardWillHide() {
    subjectDetailsView.contentInset = .zero
  }

  private func resizeKeyboard(toHeight height: Double) {
    // When the review view is embedded in a lesson view controller, the review view doesn't extend
    // all the way to the bottom - the page selector view is below it.  Take this into account:
    // find out how far the bottom of our UIView is from the bottom of the window, and subtract that
    // distance from the constraint height.
    guard let window = view.window else {
      return
    }
    let viewBottomLeft = view.convert(CGPoint(x: 0.0, y: view.bounds.maxY),
                                      to: window)
    let windowBottom = window.bounds.maxY
    let distanceFromViewBottomToWindowBottom = windowBottom - viewBottomLeft.y
    let insetHeight = max(0, CGFloat(height) - distanceFromViewBottomToWindowBottom)

    answerFieldToBottomConstraint.constant = insetHeight

    // When the keyboard changes size by a small amount (the autocorrect bar is shown/hidden) try
    // to avoid moving the question label by offsetting its bottom constraint by the same amount the
    // keyboard moved.
    if let previousKeyboardInsetHeight = previousKeyboardInsetHeight,
       abs(insetHeight - previousKeyboardInsetHeight) <= kSmallKeyboardHeightChange {
      questionLabelBottomConstraint.constant = previousKeyboardInsetHeight - insetHeight
    } else {
      questionLabelBottomConstraint.constant = 0
      previousKeyboardInsetHeight = insetHeight
    }

    var subjectDetailsViewInset = subjectDetailsView.contentInset
    subjectDetailsViewInset.bottom = insetHeight
    subjectDetailsView.contentInset = subjectDetailsViewInset

    UIView.beginAnimations(nil, context: nil)
    UIView.setAnimationDuration(animationDuration)
    UIView.setAnimationCurve(animationCurve)
    UIView.setAnimationBeginsFromCurrentState(true)

    view.layoutIfNeeded()

    UIView.commitAnimations()
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segue.identifier {
    case "reviewSummary":
      let vc = segue.destination as! ReviewSummaryViewController
      vc.setup(services: services, items: session.completedReviews)
    case "subjectDetails":
      let vc = segue.destination as! SubjectDetailsViewController
      vc.setup(services: services, subject: sender as! TKMSubject)
    default:
      break
    }
  }

  @objc public func endReviewSession() {
    performSegue(withIdentifier: "reviewSummary", sender: self)
  }

  // MARK: - Setup

  private func randomTask() {
    TKMStyle.withTraitCollection(traitCollection) {
      if session.activeQueueLength == 0 {
        delegate.finishedAllReviewItems(self)
        return
      }

      // Update the progress labels.
      let queueLength = Int(session.activeQueueLength + session.reviewQueueLength)
      let doneText = String(session.reviewsCompleted)
      let queueText = String(queueLength)
      let wrapUpText = String(session.activeQueueLength)

      // Update the progress bar.
      let totalLength = queueLength + session.reviewsCompleted
      if totalLength == 0 {
        progressBar.setProgress(0.0, animated: true)
      } else {
        progressBar.setProgress(Float(session.reviewsCompleted) / Float(totalLength),
                                animated: true)
      }

      // Choose a random task from the active queue.
      session.nextTask()

      // Fill the question labels.
      var subjectTypePrompt: String
      var taskTypePrompt: String
      var promptGradient: [CGColor]
      var promptTextColor: UIColor
      var taskTypePlaceholder: String

      switch session.activeAssignment.subjectType {
      case .kanji:
        subjectTypePrompt = "Kanji"
      case .radical:
        subjectTypePrompt = "Radical"
      case .vocabulary:
        subjectTypePrompt = "Vocabulary"
      default:
        fatalError()
      }
      switch session.activeTaskType! {
      case .meaning:
        kanaInput.enabled = false
        taskTypePrompt = session.activeAssignment.subjectType == .radical ? "Name" : "Meaning"
        promptGradient = TKMStyle.meaningGradient
        promptTextColor = kMeaningTextColor
        taskTypePlaceholder = "Your Response"
        if Settings.ankiMode {
          taskTypePlaceholder = "Show answer"
        }
      case .reading:
        kanaInput.enabled = true
        taskTypePrompt = "Reading"
        promptGradient = TKMStyle.readingGradient
        promptTextColor = kReadingTextColor
        taskTypePlaceholder = "答え"
        if Settings.ankiMode {
          taskTypePlaceholder = "答えを見せる"
        }
      }

      if session.activeAssignment.subjectType != .radical,
         Settings.ankiMode,
         Settings.ankiModeCombineReadingMeaning {
        taskTypePrompt = Settings.meaningFirst ? "Meaning + Reading" : "Reading + Meaning"
      }

      // Choose a random font.
      currentFontName = randomFont(thatCanRenderText: session.activeSubject.japanese)

      let boldFont = UIFont.boldSystemFont(ofSize: promptLabel!.font.pointSize)
      let prompt = NSMutableAttributedString(string: subjectTypePrompt + " " + taskTypePrompt)
      prompt.setAttributes([NSAttributedString.Key.font: boldFont],
                           range: NSRange(location: prompt.length - taskTypePrompt.count,
                                          length: taskTypePrompt.count))

      // Text color.
      promptLabel!.textColor = promptTextColor

      // Submit button.

      if Settings.allowSkippingReviews {
        // Change the skip button icon.
        submitButton.setImage(skipImage, for: .normal)
      } else if !Settings.ankiMode {
        submitButton.isEnabled = false
      } else {
        // Hide the submit button in Anki mode if skipping reviews are off
        submitButton.isHidden = true
      }

      // Background gradients.
      questionBackground
        .animateColors(to: TKMStyle.gradient(forAssignment: session.activeAssignment),
                       duration: animationDuration)
      promptBackground.animateColors(to: promptGradient, duration: animationDuration)

      // Accessibility.
      successRateLabel.accessibilityLabel = session.successRateText + " correct so far"
      doneLabel.accessibilityLabel = doneText + " done"
      queueLabel.accessibilityLabel = queueText + " remaining"
      questionLabel.accessibilityLabel = "Japanese " + subjectTypePrompt + ". Question"
      levelLabel.accessibilityLabel = "srs level \(session.activeAssignment.srsStage)"

      answerField.text = nil
      answerField.textColor = TKMStyle.Color.label
      answerField.backgroundColor = TKMStyle.Color.background
      answerField.placeholder = taskTypePlaceholder
      if let firstReading = session.activeSubject.primaryReadings.first {
        kanaInput.alphabet = (firstReading.hasType && firstReading.type == .onyomi &&
          Settings.useKatakanaForOnyomi) ? .katakana : .hiragana
      } else {
        kanaInput.alphabet = .hiragana
      }

      answerField.useJapaneseKeyboard = Settings
        .autoSwitchKeyboard && session.activeTaskType == .reading

      if Settings.showSRSLevelIndicator {
        levelLabel.attributedText = getDots(stage: session.activeAssignment.srsStage)
      } else {
        levelLabel.attributedText = nil
      }

      let setupContextFunc = {
        (ctx: AnimationContext) in
        if !(self.questionLabel.attributedText?
          .isEqual(to: self.session.activeSubject.japaneseText) ?? false) ||
          self.questionLabel.font.fontName != self.currentFontName {
          ctx.addFadingLabel(original: self.questionLabel!)
          self.questionLabel
            .font = UIFont(name: self.currentFontName, size: self.questionLabelFontSize())
          self.questionLabel.attributedText = self.session.activeSubject.japaneseText
        }
        if self.wrapUpLabel.text != wrapUpText {
          ctx.addFadingLabel(original: self.wrapUpLabel!)
          self.wrapUpLabel.text = wrapUpText
        }
        if self.successRateLabel.text != self.session.successRateText {
          ctx.addFadingLabel(original: self.successRateLabel!)
          self.successRateLabel.text = self.session.successRateText
        }
        if self.doneLabel.text != doneText {
          ctx.addFadingLabel(original: self.doneLabel!)
          self.doneLabel.text = doneText
        }
        if self.queueLabel.text != queueText {
          ctx.addFadingLabel(original: self.queueLabel!)
          self.queueLabel.text = queueText
        }
        if self.promptLabel.attributedText?.string != prompt.string {
          ctx.addFadingLabel(original: self.promptLabel!)
          self.promptLabel.attributedText = prompt
        }
      }
      animateSubjectDetailsView(shown: false, setupContextFunc: setupContextFunc)
    }
  }

  // MARK: - Random fonts

  func fontsThatCanRenderText(_ text: String, exclude: [String]?) -> [String] {
    var availableFonts: [String] = []

    for filename in Settings.selectedFonts {
      if let font = services.fontLoader.font(fileName: filename) {
        if let ex = exclude, ex.contains(font.fontName) {
          continue
        }
        if font.canRender(text) {
          availableFonts.append(font.fontName)
        }
      }
    }

    return availableFonts
  }

  func nextCustomFont(thatCanRenderText _: String) -> String? {
    if let availableFonts = availableFonts,
       let index = availableFonts.firstIndex(of: currentFontName) {
      if index + 1 >= availableFonts.count {
        return availableFonts.first
      } else {
        return availableFonts[index + 1]
      }
    }
    return nil
  }

  func previousCustomFont(thatCanRenderText _: String) -> String? {
    if let availableFonts = availableFonts,
       let index = availableFonts.firstIndex(of: currentFontName) {
      if index == 0 {
        return availableFonts.last
      } else {
        return availableFonts[index - 1]
      }
    }
    return nil
  }

  func randomFont(thatCanRenderText text: String) -> String {
    if delegate.allowsCustomFonts() {
      // Re-set the supported fonts when we pick a random one as that is the first
      // step.
      availableFonts = fontsThatCanRenderText(text, exclude: nil).sorted()
      return availableFonts?.randomElement() ?? TKMStyle.japaneseFontName
    } else {
      return TKMStyle.japaneseFontName
    }
  }

  // MARK: - Animation

  private func animateSubjectDetailsView(shown: Bool,
                                         setupContextFunc: ((AnimationContext) -> Void)?) {
    let cheats = delegate.allowsCheats(forReviewItem: session.activeTask)

    if shown {
      subjectDetailsView.isHidden = false
      if cheats, !Settings.ankiMode {
        addSynonymButton.isHidden = false
      }
      if Settings.ankiMode, Settings.allowSkippingReviews {
        submitButton.isHidden = true
      }
    } else {
      if previousSubject != nil {
        previousSubjectLabel?.isHidden = false
        previousSubjectButton.isHidden = false
      }
      if Settings.ankiMode, Settings.allowSkippingReviews {
        submitButton.isHidden = false
      }
    }

    // Change the submit button icon.
    let submitButtonImage = shown ? forwardArrowImage :
      (Settings.allowSkippingReviews ? skipImage : tickImage)
    submitButton.setImage(submitButtonImage, for: .normal)

    // We have to do the UIView animation this way (rather than using the block syntax) so we can
    // set
    // UIViewAnimationCurve.  Create a context to pass to the stop selector.
    let context = AnimationContext(cheats: cheats, subjectDetailsViewShown: shown)
    if let setupContextFunc = setupContextFunc {
      setupContextFunc(context)
    }

    isAnimatingSubjectDetailsView = true

    UIView.beginAnimations(nil, context: Unmanaged.passRetained(context).toOpaque())
    UIView.setAnimationDelegate(self)
    UIView.setAnimationDidStop(#selector(animationDidStop(animationID:finished:context:)))
    UIView.setAnimationDuration(animationDuration)
    UIView.setAnimationCurve(animationCurve)
    UIView.setAnimationBeginsFromCurrentState(false)

    // Constraints.
    answerFieldToBottomConstraint.isActive = !shown
    if shown {
      questionLabelBottomConstraint.constant = 0
    }

    // Enable/disable the answer field, and set its first responder status.
    // This makes the keyboard appear or disappear immediately.  We need this animation to happen
    // here so it's in sync with the others.
    answerField.isEnabled = !shown && !Settings.ankiMode
    if !shown {
      answerField.becomeFirstResponder()
    } else {
      answerField.resignFirstResponder()
    }

    // Scale the text in the question label.
    let scale = shown ? 0.7 : 1.0
    questionLabel.transform = CGAffineTransform(scaleX: CGFloat(scale), y: CGFloat(scale))

    view.layoutIfNeeded()

    context.animateFadingLabels()

    // Fade the controls.
    subjectDetailsView.alpha = shown ? 1.0 : 0.0
    if cheats {
      addSynonymButton.alpha = shown ? 1.0 : 0.0
    }
    revealAnswerButton.alpha = 0.0
    previousSubjectLabel?.alpha = shown ? 0.0 : 1.0
    previousSubjectButton.alpha = shown ? 0.0 : 1.0

    // Change the foreground color of the answer field.
    answerField.textColor = shown ? .systemRed : TKMStyle.Color.label

    // Scroll to the top.
    subjectDetailsView
      .setContentOffset(CGPoint(x: 0, y: -subjectDetailsView.contentInset.top), animated: false)

    UIView.commitAnimations()
  }

  @objc func animationDidStop(animationID _: NSString,
                              finished _: NSNumber,
                              context: UnsafeMutableRawPointer) {
    let ctx = Unmanaged<AnimationContext>.fromOpaque(context).takeRetainedValue()

    isAnimatingSubjectDetailsView = false

    revealAnswerButton.isHidden = true
    if ctx.subjectDetailsViewShown {
      previousSubjectLabel?.isHidden = true
      previousSubjectButton.isHidden = true
    } else {
      subjectDetailsView.isHidden = true
      if ctx.cheats {
        addSynonymButton.isHidden = true
      }
      answerField.becomeFirstResponder()
    }

    // This makes sure taps are still processed and not ignored, even when the closing animation
    // after a button press was not completed
    if Settings.ankiMode, ankiModeCachedSubmit { submit() }
  }

  // MARK: - Previous subject button

  func animateLabelToPreviousSubjectButton(_ label: UILabel) {
    guard let previousSubject = previousSubject else {
      return
    }

    let oldLabelCenter = label.center
    let labelBounds = CGRect(origin: CGPoint.zero, size: label.sizeThatFits(CGSize.zero))
    label.bounds = labelBounds
    label.center = oldLabelCenter

    let newButtonWidth =
      kPreviousSubjectButtonPadding * 2 + labelBounds.size.width * kPreviousSubjectScale
    let newButtonHeight =
      kPreviousSubjectButtonPadding * 2 + labelBounds.size.height * kPreviousSubjectScale

    var newGradient: [CGColor]!
    TKMStyle.withTraitCollection(traitCollection) {
      newGradient = TKMStyle.gradient(forSubject: previousSubject)
    }

    view.layoutIfNeeded()
    UIView.animate(withDuration: kPreviousSubjectAnimationDuration,
                   delay: 0.0,
                   options: .curveEaseOut,
                   animations: {
                     label
                       .transform = CGAffineTransform(scaleX: kPreviousSubjectScale,
                                                      y: kPreviousSubjectScale)

                     label.translatesAutoresizingMaskIntoConstraints = false
                     let centerYConstraint =
                       NSLayoutConstraint(item: label,
                                          attribute: .centerY,
                                          relatedBy: .equal,
                                          toItem: self.previousSubjectButton,
                                          attribute: .centerY,
                                          multiplier: 1.0,
                                          constant: 0)
                     let centerXConstraint =
                       NSLayoutConstraint(item: label,
                                          attribute: .centerX,
                                          relatedBy: .equal,
                                          toItem: self.previousSubjectButton,
                                          attribute: .centerX,
                                          multiplier: 1.0,
                                          constant: 0)
                     self.view.addConstraints([centerXConstraint, centerYConstraint])

                     self.previousSubjectButtonWidthConstraint.constant = newButtonWidth
                     self.previousSubjectButtonHeightConstraint.constant = newButtonHeight
                     self.view.layoutIfNeeded()

                     self.previousSubjectGradient.colors = newGradient
                     self.previousSubjectGradient.frame = self.previousSubjectButton.bounds
                     self.previousSubjectButton.alpha = 1.0

                     self.previousSubjectLabel?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                     self.previousSubjectLabel?.alpha = 0.01
                   }) { (_: Bool) in
      self.previousSubjectLabel?.removeFromSuperview()
      self.previousSubjectLabel = label
    }
  }

  @IBAction func previousSubjectButtonPressed(_: Any) {
    performSegue(withIdentifier: "subjectDetails", sender: previousSubject)
  }

  // MARK: - Question label fonts

  func setCustomQuestionLabelFont(useCustomFont: Bool) {
    let fontName = useCustomFont ? currentFontName! : TKMStyle.japaneseFontName
    questionLabel.font = UIFont(name: fontName, size: questionLabelFontSize())
  }

  @objc func didShortPressQuestionLabel(_: UITapGestureRecognizer) {
    toggleFont()
    if Settings.ankiMode {
      if !isAnimatingSubjectDetailsView { submit() }
      else { ankiModeCachedSubmit = true }
    }
  }

  @objc func didSwipeQuestionLabel(_ sender: UISwipeGestureRecognizer) {
    if sender.direction == .left {
      showNextCustomFont()
    } else if sender.direction == .right {
      showPreviousCustomFont()
    }
  }

  @objc func showNextCustomFont() {
    currentFontName = nextCustomFont(thatCanRenderText: session.activeSubject.japanese) ??
      TKMStyle.japaneseFontName
    setCustomQuestionLabelFont(useCustomFont: true)
  }

  @objc func showPreviousCustomFont() {
    currentFontName = previousCustomFont(thatCanRenderText: session.activeSubject.japanese) ??
      TKMStyle.japaneseFontName
    setCustomQuestionLabelFont(useCustomFont: true)
  }

  func questionLabelFontSize() -> CGFloat {
    if UIDevice.current.userInterfaceIdiom == .pad {
      return CGFloat(defaultFontSize * 2.5 * Double(Settings.fontSize))
    } else {
      return CGFloat(defaultFontSize * Double(Settings.fontSize))
    }
  }

  @objc func toggleFont() {
    let useCustomFont = questionLabel.font.fontName == TKMStyle.japaneseFontName
    setCustomQuestionLabelFont(useCustomFont: useCustomFont)
  }

  // MARK: - Menu button

  @IBAction func menuButtonPressed(_: Any) {
    delegate.tappedMenuButton?(reviewViewController: self, menuButton: menuButton)
  }

  // MARK: - Wrapping up

  @objc public var wrappingUp: Bool {
    get {
      session.wrappingUp
    }
    set {
      session.wrappingUp = newValue
      wrapUpIcon.isHidden = !newValue
      wrapUpLabel.isHidden = !newValue
    }
  }

  // MARK: - Submitting answers

  func answerFieldValueDidChange() {
    let text = answerField.text!.trimmingCharacters(in: .whitespaces)

    if Settings.allowSkippingReviews {
      let newImage = text.isEmpty ? skipImage : tickImage
      UIView
        .transition(with: submitButton, duration: 0.1,
                    options: .transitionCrossDissolve, animations: {
                      self.submitButton.setImage(newImage, for: .normal)
                    }, completion: nil)
    } else {
      submitButton.isEnabled = Settings.ankiMode || !text.isEmpty
    }
  }

  func textField(_: UITextField, shouldChangeCharactersIn _: NSRange,
                 replacementString _: String) -> Bool {
    DispatchQueue.main.async {
      self.answerFieldValueDidChange()
    }
    return true
  }

  @IBAction func submitButtonPressed(_: Any) {
    enterKeyPressed()
  }

  func textFieldShouldReturn(_: UITextField) -> Bool {
    enterKeyPressed()

    // Keep the cursor in the text field except when subject details are displayed.
    return !subjectDetailsView.isHidden
  }

  @objc func enterKeyPressed() {
    if !submitButton.isEnabled {
      return
    }
    if Settings.allowSkippingReviews,
       answerField.text!.trimmingCharacters(in: .whitespaces).isEmpty {
      markAnswer(.AskAgainLater)
      return
    }
    if !answerField.isEnabled, !Settings.ankiMode {
      if !subjectDetailsView.isHidden {
        subjectDetailsView.saveStudyMaterials()
      }
      randomTask()
    } else {
      submit()
    }
  }

  /// Used during wrong answers to reset the text field.
  @objc func backspaceKeyPressed() {
    answerField.text = nil
    answerField.textColor = TKMStyle.Color.label
    answerField.isEnabled = true
    answerField.becomeFirstResponder()
  }

  func submit() {
    if Settings.ankiMode {
      ankiModeCachedSubmit = false
      // Mark the answer incorrect to show the details. This can still be overriden.
      let answersRevealed = !subjectDetailsView.isHidden
      if !answersRevealed { markAnswer(.Incorrect) }
      if Settings.showAnswerImmediately || answersRevealed { addSynonymButtonPressed(true) }
      return
    }

    answerField.text = AnswerChecker.normalizedString(answerField.text ?? "",
                                                      taskType: session.activeTaskType,
                                                      alphabet: kanaInput.alphabet)
    let result = AnswerChecker.checkAnswer(answerField.text!,
                                           subject: session.activeSubject,
                                           studyMaterials: session.activeStudyMaterials,
                                           taskType: session.activeTaskType,
                                           localCachingClient: services.localCachingClient)

    switch result {
    case .Precise:
      markAnswer(.Correct)
    case .Imprecise:
      if Settings.exactMatch { shakeView(answerField) }
      else { markAnswer(.Correct) }
    case .Incorrect:
      markAnswer(.Incorrect)
    case .OtherKanjiReading:
      shakeView(answerField)
    case .ContainsInvalidCharacters:
      shakeView(answerField)
    }
  }

  func shakeView(_ view: UIView) {
    let animation = CABasicAnimation(keyPath: "position")
    animation.duration = 0.1
    animation.repeatCount = 3
    animation.autoreverses = true
    animation.fromValue = NSValue(cgPoint: CGPoint(x: view.center.x - 10, y: view.center.y))
    animation.toValue = NSValue(cgPoint: CGPoint(x: view.center.x + 10, y: view.center.y))

    view.layer.add(animation, forKey: nil)
  }

  private func markAnswer(_ result: AnswerResult) {
    if result == .AskAgainLater {
      // Take the task out of the queue so it comes back later.
      session.moveActiveTaskToEnd()
      randomTask()
      return
    }

    if result.correct {
      hapticGenerator.impactOccurred()
      hapticGenerator.prepare()
    }

    // Mark the task.
    var marked = session.markAnswer(result, isPracticeSession: isPracticeSession)

    // Show a new task if it was correct.
    if result != .Incorrect {
      if session.activeAssignment.subjectType != .radical, // or kana mode?
         Settings.ankiMode,
         Settings.ankiModeCombineReadingMeaning {
        session.nextTask()
        marked = session.markAnswer(.Correct)
      }

      if Settings.playAudioAutomatically, session.activeTaskType == .reading,
         let subject = session.activeSubject,
         subject.hasVocabulary, !subject.vocabulary.audio.isEmpty {
        services.audio.play(subjectID: subject.id, delegate: nil)
      }

      var previousSubjectLabel: UILabel?
      if marked.subjectFinished, showSubjectHistory {
        previousSubjectLabel = copyLabel(questionLabel)
        previousSubject = session.activeSubject
      }
      randomTask()
      if result.correct {
        // We must start the success animations *after* all the UI elements have been moved to their
        // new locations by randomTask(), so that, for example, the success sparkles animate from
        // the final position of the answerField, not the original position.
        SuccessAnimation.run(answerField: answerField, doneLabel: doneLabel,
                             srsLevelLabel: levelLabel, isSubjectFinished: marked.subjectFinished,
                             didLevelUp: marked.didLevelUp, newSrsStage: marked.newSrsStage)
      }

      if let previousSubjectLabel = previousSubjectLabel {
        animateLabelToPreviousSubjectButton(previousSubjectLabel)
      }
      return
    }

    // Otherwise show the correct answer.
    if !Settings.showAnswerImmediately, !Settings.ankiMode {
      revealAnswerButton.isHidden = false
      UIView.animate(withDuration: animationDuration,
                     animations: {
                       self.answerField.textColor = .systemRed
                       self.answerField.isEnabled = false
                       self.revealAnswerButton.alpha = 1.0
                       self.submitButton.setImage(self.forwardArrowImage, for: .normal)
                     })
    } else {
      revealAnswerButtonPressed(revealAnswerButton!)
    }
  }

  @IBAction func revealAnswerButtonPressed(_: Any) {
    let task = Settings.showFullAnswer ? nil : session.activeTask
    subjectDetailsView.update(withSubject: session.activeSubject,
                              studyMaterials: session.activeStudyMaterials,
                              assignment: session.activeAssignment, task: task)

    let setupContextFunc = { (ctx: AnimationContext) in
      if self.questionLabel.font.fontName != TKMStyle.japaneseFontName {
        ctx.addFadingLabel(original: self.questionLabel)
        self.questionLabel.font = UIFont(name: TKMStyle.japaneseFontName,
                                         size: self.questionLabelFontSize())
      }
    }
    animateSubjectDetailsView(shown: true, setupContextFunc: setupContextFunc)
  }

  // MARK: - Ignoring incorrect answers

  @IBAction func addSynonymButtonPressed(_: Any) {
    let c = UIAlertController(title: "Ignore incorrect answer?",
                              message:
                              "Don't cheat!  Only use this if you promise you " +
                                "knew the correct answer.",
                              preferredStyle: .actionSheet)
    c.popoverPresentationController?.sourceView = addSynonymButton
    c.popoverPresentationController?.sourceRect = addSynonymButton.bounds

    c.addAction(UIAlertAction(title: "My answer was correct",
                              style: .default,
                              handler: { _ in self.markCorrect() }))
    if Settings.ankiMode {
      c.addAction(UIAlertAction(title: "My answer was incorrect",
                                style: .default,
                                handler: { _ in self.markIncorrect() }))
    }
    c.addAction(UIAlertAction(title: "Ask again later",
                              style: .default,
                              handler: { _ in self.askAgain() }))

    if session.activeTaskType == .meaning {
      c.addAction(UIAlertAction(title: "Add synonym",
                                style: .default,
                                handler: { _ in self.addSynonym() }))
    }

    c.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(c, animated: true, completion: nil)
  }

  @objc func markCorrect() {
    markAnswer(.OverrideAnswerCorrect)
  }

  @objc func markIncorrect() {
    randomTask()
  }

  @objc func askAgain() {
    markAnswer(.AskAgainLater)
  }

  @objc func addSynonym() {
    if let text = answerField.text {
      session.addSynonym(text)
    }
    markAnswer(.OverrideAnswerCorrect)
  }

  // For no particularly apparent reason, this seemingly pointless implementation
  // means that holding down the command key after (say) pressing ⌘C does not
  // repeat the action continuously on all subsequent reviews
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    super.canPerformAction(action, withSender: sender)
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    performSegue(withIdentifier: "subjectDetails", sender: subject)
  }

  // MARK: - Keyboard navigation

  override var canBecomeFirstResponder: Bool {
    true
  }

  override var keyCommands: [UIKeyCommand]? {
    let keyboardEnter = UIKeyCommand(input: "\r",
                                     modifierFlags: [],
                                     action: #selector(enterKeyPressed),
                                     discoverabilityTitle: "Continue")
    let numericKeyPadEnter = UIKeyCommand(input: "\u{3}",
                                          modifierFlags: [],
                                          action: #selector(enterKeyPressed),
                                          discoverabilityTitle: "Continue")
    var keyCommands: [UIKeyCommand] = []

    if !answerField.isEnabled, subjectDetailsView.isHidden {
      // Continue when a wrong answer has been entered but the subject details view is hidden.
      keyCommands.append(contentsOf: [UIKeyCommand(input: "\u{8}",
                                                   modifierFlags: [],
                                                   action: #selector(backspaceKeyPressed),
                                                   discoverabilityTitle: "Clear wrong answer"),
                                      keyboardEnter,
                                      numericKeyPadEnter])
    }

    if !subjectDetailsView.isHidden {
      // Key commands when showing the detail view
      keyCommands.append(contentsOf: [UIKeyCommand(input: " ",
                                                   modifierFlags: [],
                                                   action: #selector(showAllInformation),
                                                   discoverabilityTitle: "Show all information"),
                                      UIKeyCommand(input: "j", modifierFlags: [],
                                                   action: #selector(playAudio)),
                                      UIKeyCommand(input: "a",
                                                   modifierFlags: [.command],
                                                   action: #selector(askAgain),
                                                   discoverabilityTitle: "Ask again later"),
                                      UIKeyCommand(input: "c",
                                                   modifierFlags: [.command],
                                                   action: #selector(markCorrect),
                                                   discoverabilityTitle: "Mark correct"),
                                      UIKeyCommand(input: "c",
                                                   modifierFlags: [.control],
                                                   action: #selector(markCorrect)),
                                      UIKeyCommand(input: "i",
                                                   modifierFlags: [.command],
                                                   action: #selector(markIncorrect),
                                                   discoverabilityTitle: "Mark incorrect"),
                                      UIKeyCommand(input: "i",
                                                   modifierFlags: [.control],
                                                   action: #selector(markIncorrect)),
                                      UIKeyCommand(input: "s",
                                                   modifierFlags: [.command],
                                                   action: #selector(addSynonym),
                                                   discoverabilityTitle: "Add as synonym"),
                                      keyboardEnter,
                                      numericKeyPadEnter])
    } else {
      if !revealAnswerButton.isHidden {
        keyCommands.append(UIKeyCommand(input: "f",
                                        modifierFlags: [],
                                        action: #selector(revealAnswerButtonPressed),
                                        discoverabilityTitle: "Reveal answer"))
      }
    }

    if Settings.selectedFonts.count > 0 {
      keyCommands.append(UIKeyCommand(input: "\t",
                                      modifierFlags: [],
                                      action: #selector(toggleFont),
                                      discoverabilityTitle: "Toggle font"))
      keyCommands.append(UIKeyCommand(input: UIKeyCommand.inputRightArrow,
                                      modifierFlags: [],
                                      action: #selector(showNextCustomFont),
                                      discoverabilityTitle: "Next font"))
      keyCommands.append(UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                                      modifierFlags: [],
                                      action: #selector(showPreviousCustomFont),
                                      discoverabilityTitle: "Previous font"))
    }
    if !previousSubjectButton.isHidden {
      keyCommands.append(UIKeyCommand(input: "p",
                                      modifierFlags: [.command],
                                      action: #selector(previousSubjectButtonPressed(_:)),
                                      discoverabilityTitle: "Previous subject"))
    }
    return keyCommands
  }

  @objc func showAllInformation() {
    if !subjectDetailsView.isHidden {
      subjectDetailsView.showAllFields()
    }
  }

  @objc func playAudio() {
    if !subjectDetailsView.isHidden {
      subjectDetailsView.playAudio()
    }
  }
}
