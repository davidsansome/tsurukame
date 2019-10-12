// Copyright 2019 David Sansome
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

private let kDefaultAnimationDuration: TimeInterval = 0.25
// Undocumented, but it's what the keyboard animations use.
private let kDefaultAnimationCurve: UIView.AnimationCurve = UIView.AnimationCurve(rawValue: 7)!

private let kPreviousSubjectScale: CGFloat = 0.25
private let kPreviousSubjectButtonPadding: CGFloat = 6.0
private let kPreviousSubjectAnimationDuration: Double = 0.3

private let kReadingGradient = [
  UIColor(red: 0.235, green: 0.235, blue: 0.235, alpha: 1.0).cgColor,
  UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0).cgColor,
]

private let kMeaningGradient = [
  UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1.0).cgColor,
  UIColor(red: 0.882, green: 0.882, blue: 0.882, alpha: 1.0).cgColor,
]

private let kReadingTextColor = UIColor.white
private let kMeaningTextColor = UIColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1.0)
private let kDefaultButtonTintColor = UIButton().tintColor

private enum AnswerResult {
  case Correct
  case Incorrect
  case OverrideAnswerCorrect
  case AskAgainLater
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
protocol ReviewViewControllerDelegate {
  func reviewViewControllerAllowsCheats(forReviewItem item: ReviewItem) -> Bool
  func reviewViewControllerFinishedAllReviewItems(_ reviewViewController: ReviewViewController)
  @objc optional func reviewViewController(_ reviewViewController: ReviewViewController,
                                           tappedMenuButton menuButton: UIButton)
}

class ReviewViewController: UIViewController, UITextFieldDelegate, TKMSubjectDelegate {
  private var kanaInput: TKMKanaInput!
  private let hapticGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.light)
  private let tickImage = UIImage(named: "confirm")
  private let forwardArrowImage = UIImage(named: "ic_arrow_forward_white")

  private var services: TKMServices!
  private var showMenuButton: Bool!
  private var showSubjectHistory: Bool!
  private weak var delegate: ReviewViewControllerDelegate!

  private var activeQueue = [ReviewItem]()
  private var reviewQueue = [ReviewItem]()
  private var completedReviews = [ReviewItem]()
  private var activeQueueSize = 1

  private var activeTaskIndex = 0 // An index into activeQueue.
  private var activeTaskType: TKMTaskType!
  private var activeTask: ReviewItem!
  private var activeSubject: TKMSubject!
  private var activeStudyMaterials: TKMStudyMaterials?

  @objc public private(set) var tasksAnsweredCorrectly = 0
  private var tasksAnswered = 0
  private var reviewsCompleted = 0

  private var lastMarkAnswerWasFirstTime = false

  private var previousSubjectGradient: CAGradientLayer!

  private var previousSubject: TKMSubject?
  private var previousSubjectLabel: UILabel?

  // These are set to match the keyboard animation.
  private var animationDuration: Double = kDefaultAnimationDuration
  private var animationCurve: UIView.AnimationCurve = kDefaultAnimationCurve

  private var currentFontName: String!
  private var normalFontName: String!
  private var defaultFontSize: Double!

  @IBOutlet private var menuButton: UIButton!
  @IBOutlet private var questionBackground: TKMGradientView!
  @IBOutlet private var promptBackground: TKMGradientView!
  @IBOutlet private var questionLabel: UILabel!
  @IBOutlet private var promptLabel: UILabel!
  @IBOutlet private var answerField: UITextField!
  @IBOutlet private var submitButton: UIButton!
  @IBOutlet private var addSynonymButton: UIButton!
  @IBOutlet private var revealAnswerButton: UIButton!
  @IBOutlet private var progressBar: UIProgressView!
  @IBOutlet private var subjectDetailsView: TKMSubjectDetailsView!
  @IBOutlet private var previousSubjectButton: UIButton!

  @IBOutlet private var wrapUpLabel: UILabel!
  @IBOutlet private var successRateLabel: UILabel!
  @IBOutlet private var doneLabel: UILabel!
  @IBOutlet private var queueLabel: UILabel!
  @IBOutlet private var wrapUpIcon: UIImageView!
  @IBOutlet private var successRateIcon: UIImageView!
  @IBOutlet private var doneIcon: UIImageView!
  @IBOutlet private var queueIcon: UIImageView!

  @IBOutlet private var answerFieldToBottomConstraint: NSLayoutConstraint!
  @IBOutlet private var answerFieldToSubjectDetailsViewConstraint: NSLayoutConstraint!
  @IBOutlet private var previousSubjectButtonWidthConstraint: NSLayoutConstraint!
  @IBOutlet private var previousSubjectButtonHeightConstraint: NSLayoutConstraint!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    kanaInput = TKMKanaInput(delegate: self)
  }

  @objc public func setup(withServices services: TKMServices,
                          items: [ReviewItem],
                          showMenuButton: Bool,
                          showSubjectHistory: Bool,
                          delegate: ReviewViewControllerDelegate) {
    self.services = services
    self.showMenuButton = showMenuButton
    self.showSubjectHistory = showSubjectHistory
    self.delegate = delegate

    reviewQueue = items

    if Settings.groupMeaningReading {
      activeQueueSize = 1
    } else {
      // TODO: Make this configurable.
      activeQueueSize = 5
    }

    reviewQueue.shuffle()
    switch Settings.reviewOrder {
    case ReviewOrder_BySRSStage:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.srsStage < b.assignment.srsStage { return true }
        if a.assignment.srsStage > b.assignment.srsStage { return false }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case ReviewOrder_CurrentLevelFirst:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.level < b.assignment.level { return false }
        if a.assignment.level > b.assignment.level { return true }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case ReviewOrder_LowestLevelFirst:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.level < b.assignment.level { return true }
        if a.assignment.level > b.assignment.level { return false }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case ReviewOrder_Random:
      break
    default:
      break
    }

    refillActiveQueue()
  }

  @objc public var activeQueueLength: Int {
    return activeQueue.count
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()

    TKMAddShadowToView(questionLabel, 1, 0.2, 4)
    TKMAddShadowToView(previousSubjectButton, 0, 0.7, 4)

    wrapUpIcon.image = UIImage(named: "baseline_access_time_black_24pt")?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)

    previousSubjectGradient = CAGradientLayer()
    previousSubjectGradient.cornerRadius = 4.0
    previousSubjectButton.layer.addSublayer(previousSubjectGradient)

    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                           name: UIResponder.keyboardWillShowNotification, object: nil)

    subjectDetailsView.setup(with: services, showHints: false, subjectDelegate: self)

    answerField.delegate = kanaInput
    answerField.addTarget(self, action: #selector(answerFieldValueDidChange), for: UIControl.Event.editingChanged)

    if !showMenuButton {
      menuButton.isHidden = true
    }

    normalFontName = kTKMJapaneseFontName
    currentFontName = normalFontName
    defaultFontSize = Double(questionLabel.font.pointSize)

    let longPressRecognizer =
      UILongPressGestureRecognizer(target: self, action: #selector(didLongPressQuestionLabel))
    longPressRecognizer.minimumPressDuration = 0
    longPressRecognizer.allowableMovement = 500
    questionBackground.addGestureRecognizer(longPressRecognizer)

    viewDidLayoutSubviews()
    randomTask()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    // Fix the extra inset at the top of the subject details view.
    subjectDetailsView.contentInset = UIEdgeInsets(top: -view.tkm_safeAreaInsets.top, left: 0, bottom: 0, right: 0)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setNavigationBarHidden(true, animated: false)
    if subjectDetailsView.isHidden {
      answerField.becomeFirstResponder()
      answerField.reloadInputViews()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    subjectDetailsView.deselectLastSubjectChipTapped()
    DispatchQueue.main.async {
      self.focusAnswerField()
    }
  }

  @objc public func focusAnswerField() {
    answerField.becomeFirstResponder()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    UIStatusBarStyle.lightContent
  }

  // MARK: - Event handlers

  @objc private func keyboardWillShow(notification: NSNotification) {
    guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
      let animationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
    else {
      return
    }
    self.animationDuration = animationDuration
    self.animationCurve = UIView.AnimationCurve(rawValue: animationCurve)!

    resizeKeyboard(toHeight: Double(keyboardFrame.size.height))
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

    answerFieldToBottomConstraint.constant = CGFloat(height) - distanceFromViewBottomToWindowBottom

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
      vc.setup(with: services, items: completedReviews)
    case "subjectDetails":
      let vc = segue.destination as! SubjectDetailsViewController
      vc.setup(with: services, subject: sender as! TKMSubject)
    default:
      break
    }
  }

  @objc public func endReviewSession() {
    performSegue(withIdentifier: "reviewSummary", sender: self)
  }

  // MARK: - Setup

  private func refillActiveQueue() {
    if wrappingUp {
      return
    }

    while activeQueue.count < activeQueueSize, reviewQueue.count != 0 {
      let item = reviewQueue.first!
      reviewQueue.removeFirst()
      activeQueue.append(item)
    }
  }

  private func randomTask() {
    if activeQueue.count == 0 {
      delegate.reviewViewControllerFinishedAllReviewItems(self)
      return
    }

    // Update the progress labels.
    var successRateText: String
    if tasksAnswered == 0 {
      successRateText = "100%"
    } else {
      successRateText = String(Int(Double(tasksAnsweredCorrectly) / Double(tasksAnswered) * 100)) + "%"
    }
    let queueLength = Int(activeQueue.count + reviewQueue.count)
    let doneText = String(reviewsCompleted)
    let queueText = String(queueLength)
    let wrapUpText = String(activeQueue.count)

    // Update the progress bar.
    let totalLength = queueLength + reviewsCompleted
    if totalLength == 0 {
      progressBar.setProgress(0.0, animated: true)
    } else {
      progressBar.setProgress(Float(reviewsCompleted) / Float(totalLength), animated: true)
    }

    // Choose a random task from the active queue.
    activeTaskIndex = Int(arc4random_uniform(UInt32(activeQueue.count)))
    activeTask = activeQueue[activeTaskIndex]
    activeSubject = services.dataLoader.load(subjectID: Int(activeTask.assignment!.subjectId))!
    activeStudyMaterials =
      services.localCachingClient?.getStudyMaterial(forID: activeTask.assignment!.subjectId)

    // Choose whether to ask the meaning or the reading.
    if activeTask.answeredMeaning {
      activeTaskType = TKMTaskType.reading
    } else if activeTask.answeredReading {
      activeTaskType = TKMTaskType.meaning
    } else if Settings.groupMeaningReading {
      activeTaskType = Settings.meaningFirst ? TKMTaskType.meaning : TKMTaskType.reading
    } else {
      activeTaskType = TKMTaskType(rawValue: TKMTaskType.RawValue(arc4random_uniform(UInt32(TKMTaskType._Max.rawValue))))!
    }

    // Fill the question labels.
    var subjectTypePrompt: String
    var taskTypePrompt: String
    var promptGradient: [CGColor]
    var promptTextColor: UIColor
    var taskTypePlaceholder: String

    switch activeTask.assignment.subjectType {
    case .kanji:
      subjectTypePrompt = "Kanji"
    case .radical:
      subjectTypePrompt = "Radical"
    case .vocabulary:
      subjectTypePrompt = "Vocabulary"
    @unknown default:
      fatalError()
    }
    switch activeTaskType! {
    case .meaning:
      kanaInput.enabled = false
      taskTypePrompt = activeTask.assignment.subjectType == .radical ? "Name" : "Meaning"
      promptGradient = kMeaningGradient
      promptTextColor = kMeaningTextColor
      taskTypePlaceholder = "Your Response"
    case .reading:
      kanaInput.enabled = true
      taskTypePrompt = "Reading"
      promptGradient = kReadingGradient
      promptTextColor = kReadingTextColor
      taskTypePlaceholder = "答え"
    case ._Max:
      fallthrough
    @unknown default:
      fatalError()
    }

    // Choose a random font.
    currentFontName = randomFont(thatCanRenderText: activeSubject.japanese)

    let boldFont = UIFont.boldSystemFont(ofSize: promptLabel!.font.pointSize)
    let prompt = NSMutableAttributedString(string: subjectTypePrompt + " " + taskTypePrompt)
    prompt.setAttributes([NSAttributedString.Key.font: boldFont],
                         range: NSRange(location: prompt.length - taskTypePrompt.count,
                                        length: taskTypePrompt.count))

    // Text color.
    promptLabel!.textColor = promptTextColor

    // Submit button.
    submitButton.isEnabled = true

    // Background gradients.
    questionBackground.animateColors(to: TKMGradientForAssignment(activeTask.assignment), duration: animationDuration)
    promptBackground.animateColors(to: promptGradient, duration: animationDuration)

    // Accessibility.
    successRateLabel.accessibilityLabel = successRateText + " correct so far"
    doneLabel.accessibilityLabel = doneText + " done"
    queueLabel.accessibilityLabel = queueText + " remaining"
    questionLabel.accessibilityLabel = "Japanese " + subjectTypePrompt + ". Question"

    answerField.text = nil
    answerField.placeholder = taskTypePlaceholder
    if let firstReading = activeSubject.primaryReadings.first {
      kanaInput.alphabet = (
        firstReading.hasType && firstReading.type == .onyomi && Settings.useKatakanaForOnyomi) ?
        .katakana : .hiragana
    } else {
      kanaInput.alphabet = .hiragana
    }

    let setupContextFunc = {
      (ctx: AnimationContext) in
      if !(self.questionLabel.attributedText?.isEqual(to: self.activeSubject.japaneseText) ?? false) ||
        self.questionLabel.font.familyName != self.currentFontName {
        ctx.addFadingLabel(original: self.questionLabel!)
        self.questionLabel.font = UIFont(name: self.currentFontName, size: self.questionLabelFontSize())
        self.questionLabel.attributedText = self.activeSubject.japaneseText
      }
      if self.wrapUpLabel.text != wrapUpText {
        ctx.addFadingLabel(original: self.wrapUpLabel!)
        self.wrapUpLabel.text = wrapUpText
      }
      if self.successRateLabel.text != successRateText {
        ctx.addFadingLabel(original: self.successRateLabel!)
        self.successRateLabel.text = successRateText
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

  // MARK: - Random fonts

  func randomFont(thatCanRenderText text: String) -> String {
    // Get the names of selected fonts.
    var selectedFontNames = [String]()
    for filename in Settings.selectedFonts ?? [] {
      if let font = services.fontLoader.font(byName: filename) {
        selectedFontNames.append(font.fontName)
      }
    }

    // Pick a random one.
    while !selectedFontNames.isEmpty {
      let fontIndex = Int(arc4random_uniform(UInt32(selectedFontNames.count)))
      let fontName = selectedFontNames[fontIndex]

      // If the font can't render the text, try another one.
      if !TKMFontCanRenderText(fontName, text) {
        selectedFontNames.remove(at: fontIndex)
        continue
      }
      return fontName
    }
    return normalFontName
  }

  // MARK: - Animation

  private func animateSubjectDetailsView(shown: Bool, setupContextFunc: ((AnimationContext) -> Void)?) {
    let cheats = delegate.reviewViewControllerAllowsCheats(forReviewItem: activeTask)

    if shown {
      subjectDetailsView.isHidden = false
      if cheats {
        addSynonymButton.isHidden = false
      }
    } else {
      if previousSubject != nil {
        previousSubjectLabel?.isHidden = false
        previousSubjectButton.isHidden = false
      }
    }

    // Change the submit button icon.
    let submitButtonImage = shown ? forwardArrowImage : tickImage
    submitButton.setImage(submitButtonImage, for: .normal)

    // We have to do the UIView animation this way (rather than using the block syntax) so we can set
    // UIViewAnimationCurve.  Create a context to pass to the stop selector.
    let context = AnimationContext(cheats: cheats, subjectDetailsViewShown: shown)
    if let setupContextFunc = setupContextFunc {
      setupContextFunc(context)
    }

    UIView.beginAnimations(nil, context: Unmanaged.passRetained(context).toOpaque())
    UIView.setAnimationDelegate(self)
    UIView.setAnimationDidStop(#selector(animationDidStop(animationID:finished:context:)))
    UIView.setAnimationDuration(animationDuration)
    UIView.setAnimationCurve(animationCurve)
    UIView.setAnimationBeginsFromCurrentState(false)

    // Constraints.
    answerFieldToBottomConstraint.isActive = !shown

    // Enable/disable the answer field, and set its first responder status.
    // This makes the keyboard appear or disappear immediately.  We need this animation to happen
    // here so it's in sync with the others.
    answerField.isEnabled = !shown
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

    // Change the background color of the answer field.
    answerField.textColor = shown ? UIColor.red : UIColor.black

    // Scroll to the top.
    subjectDetailsView.setContentOffset(CGPoint(x: 0, y: -subjectDetailsView.contentInset.top), animated: false)

    UIView.commitAnimations()
  }

  @objc func animationDidStop(animationID _: NSString, finished _: NSNumber, context: UnsafeMutableRawPointer) {
    let ctx = Unmanaged<AnimationContext>.fromOpaque(context).takeRetainedValue()

    revealAnswerButton.isHidden = true
    if ctx.subjectDetailsViewShown {
      previousSubjectLabel?.isHidden = true
      previousSubjectButton.isHidden = true
    } else {
      subjectDetailsView.isHidden = true
      if ctx.cheats {
        addSynonymButton.isHidden = true
      }
    }
  }

  // MARK: - Previous subject button

  func animateLabelToPreviousSubjectButton(_ label: UILabel) {
    let oldLabelCenter = label.center
    let labelBounds = CGRect(origin: CGPoint.zero, size: label.sizeThatFits(CGSize.zero))
    label.bounds = labelBounds
    label.center = oldLabelCenter

    let newButtonWidth =
      kPreviousSubjectButtonPadding * 2 + labelBounds.size.width * kPreviousSubjectScale
    let newButtonHeight =
      kPreviousSubjectButtonPadding * 2 + labelBounds.size.height * kPreviousSubjectScale

    let newGradient = TKMGradientForSubject(previousSubject)

    view.layoutIfNeeded()
    UIView.animate(withDuration: kPreviousSubjectAnimationDuration,
                   delay: 0.0,
                   options: .curveEaseOut,
                   animations: {
                     label.transform = CGAffineTransform(scaleX: kPreviousSubjectScale, y: kPreviousSubjectScale)

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
    let fontName = useCustomFont ? currentFontName! : normalFontName!
    questionLabel.font = UIFont(name: fontName, size: questionLabelFontSize())
  }

  @objc func didLongPressQuestionLabel(_ gestureRecognizer: UILongPressGestureRecognizer) {
    let answered = !subjectDetailsView.isHidden
    if gestureRecognizer.state == .began {
      setCustomQuestionLabelFont(useCustomFont: answered)
    } else if gestureRecognizer.state == .ended {
      setCustomQuestionLabelFont(useCustomFont: !answered)
    }
  }

  func questionLabelFontSize() -> CGFloat {
    if UI_USER_INTERFACE_IDIOM() == .pad {
      return CGFloat(defaultFontSize * 2.5)
    } else {
      return CGFloat(defaultFontSize)
    }
  }

  @objc func toggleFont() {
    let useCustomFont =
      questionLabel.font == TKMJapaneseFontLight(questionLabel.font.pointSize)
    setCustomQuestionLabelFont(useCustomFont: useCustomFont)
  }

  // MARK: - Menu button

  @IBAction func menuButtonPressed(_: Any) {
    delegate.reviewViewController?(self, tappedMenuButton: menuButton)
  }

  // MARK: - Wrapping up

  private var _isWrappingUp = false
  @objc public var wrappingUp: Bool {
    get {
      _isWrappingUp
    }
    set {
      _isWrappingUp = newValue
      wrapUpIcon.isHidden = !_isWrappingUp
      wrapUpLabel.isHidden = !_isWrappingUp
    }
  }

  // MARK: - Submitting answers

  @objc func answerFieldValueDidChange() {
    let text = answerField.text?.trimmingCharacters(in: .whitespaces)
    submitButton.isEnabled = !(text?.isEmpty ?? true)
  }

  func textField(_: UITextField, shouldChangeCharactersIn _: NSRange, replacementString _: String) -> Bool {
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
    return true
  }

  @objc func enterKeyPressed() {
    if !submitButton.isEnabled {
      return
    }
    if !answerField.isEnabled {
      randomTask()
    } else {
      submit()
    }
  }

  func submit() {
    answerField.text = AnswerChecker.normalizedString(answerField.text ?? "",
                                                      taskType: activeTaskType,
                                                      alphabet: kanaInput.alphabet)
    let result = AnswerChecker.checkAnswer(answerField.text!,
                                           subject: activeSubject,
                                           studyMaterials: activeStudyMaterials,
                                           taskType: activeTaskType,
                                           dataLoader: services.dataLoader)

    switch result {
    case .Precise:
      markAnswer(.Correct)
    case .Imprecise:
      markAnswer(.Correct)
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
    animation.duration = 0.0
    animation.repeatCount = 3
    animation.autoreverses = true
    animation.fromValue = NSValue(cgPoint: CGPoint(x: view.center.x - 10, y: view.center.y))
    animation.toValue = NSValue(cgPoint: CGPoint(x: view.center.x + 10, y: view.center.y))

    view.layer.add(animation, forKey: nil)
  }

  private func markAnswer(_ result: AnswerResult) {
    if result == .AskAgainLater {
      // Take the task out of the queue so it comes back later.
      activeQueue.remove(at: activeTaskIndex)
      activeTask.reset()
      reviewQueue.append(activeTask)
      refillActiveQueue()
      randomTask()
      return
    }

    let correct = result == .Correct || result == .OverrideAnswerCorrect

    if correct {
      hapticGenerator.impactOccurred()
      hapticGenerator.prepare()
    }

    // Mark the task.
    var firstTimeAnswered = false
    switch activeTaskType {
    case .meaning:
      firstTimeAnswered = !activeTask.answer.hasMeaningWrong
      if firstTimeAnswered ||
        (lastMarkAnswerWasFirstTime && result == .Correct) {
        activeTask.answer.meaningWrong = !correct
      }
      activeTask.answeredMeaning = correct
    case .reading:
      firstTimeAnswered = !activeTask.answer.hasReadingWrong
      if firstTimeAnswered ||
        (lastMarkAnswerWasFirstTime && result == .Correct) {
        activeTask.answer.readingWrong = !correct
      }
      activeTask.answeredReading = correct
    default:
      fatalError()
    }
    lastMarkAnswerWasFirstTime = firstTimeAnswered

    // Update stats.
    switch result {
    case .Correct:
      tasksAnswered += 1
      tasksAnsweredCorrectly += 1

    case .Incorrect:
      tasksAnswered += 1

    case .OverrideAnswerCorrect:
      tasksAnsweredCorrectly += 1

    case .AskAgainLater:
      // Handled above.
      fatalError()
    }

    // Remove it from the active queue if that was the last part.
    let isSubjectFinished =
      activeTask.answeredMeaning && (activeSubject.hasRadical || activeTask.answeredReading)
    let didLevelUp = (!activeTask.answer.readingWrong && !activeTask.answer.meaningWrong)
    let newSrsStage =
      didLevelUp ? activeTask.assignment.srsStage + 1 : activeTask.assignment.srsStage - 1
    if isSubjectFinished {
      let date = Int32(Date().timeIntervalSince1970)
      if date > activeTask.assignment!.availableAt {
        activeTask.answer.createdAt = date
      }

      services.localCachingClient!.sendProgress([activeTask.answer])

      reviewsCompleted += 1
      completedReviews.append(activeTask)
      activeQueue.remove(at: activeTaskIndex)
      refillActiveQueue()
    }

    // Show a new task if it was correct.
    if result != .Incorrect {
      if Settings.playAudioAutomatically, activeTaskType == .reading,
        activeSubject.hasVocabulary, activeSubject.vocabulary.audioIdsArray_Count > 0 {
        services.audio.play(forSubjectID: activeSubject.id_p, delegate: nil)
      }

      var previousSubjectLabel: UILabel?
      if isSubjectFinished, showSubjectHistory {
        previousSubjectLabel = copyLabel(questionLabel)
        previousSubject = activeSubject
      }
      randomTask()
      if correct {
        RunSuccessAnimation(answerField, doneLabel, isSubjectFinished, didLevelUp, newSrsStage)
      }
      if let previousSubjectLabel = previousSubjectLabel {
        animateLabelToPreviousSubjectButton(previousSubjectLabel)
      }
      return
    }

    // Otherwise show the correct answer.
    if !Settings.showAnswerImmediately, firstTimeAnswered {
      revealAnswerButton.isHidden = false
      UIView.animate(withDuration: animationDuration,
                     animations: {
                       self.answerField.textColor = UIColor.red
                       self.answerField.isEnabled = false
                       self.revealAnswerButton.alpha = 1.0
                       self.submitButton.setImage(self.forwardArrowImage, for: .normal)
      })
    } else {
      revealAnswerButtonPressed(revealAnswerButton!)
    }
  }

  @IBAction func revealAnswerButtonPressed(_: Any) {
    subjectDetailsView.update(with: activeSubject, studyMaterials: activeStudyMaterials)

    let setupContextFunc = { (ctx: AnimationContext) in
      if self.questionLabel.font.familyName != self.normalFontName {
        ctx.addFadingLabel(original: self.questionLabel)
        self.questionLabel.font = UIFont(name: self.normalFontName, size: self.questionLabelFontSize())
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
    c.addAction(UIAlertAction(title: "Ask again later",
                              style: .default,
                              handler: { _ in self.askAgain() }))

    if activeTaskType == .meaning {
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

  @objc func askAgain() {
    markAnswer(.AskAgainLater)
  }

  @objc func addSynonym() {
    if activeStudyMaterials == nil {
      activeStudyMaterials = TKMStudyMaterials()
      activeStudyMaterials!.subjectId = activeSubject.id_p
      activeStudyMaterials!.subjectType = activeSubject.subjectTypeString
    }
    activeStudyMaterials!.meaningSynonymsArray.add(answerField.text!)
    services.localCachingClient?.updateStudyMaterial(activeStudyMaterials!)
    markAnswer(.OverrideAnswerCorrect)
  }

  // For no particularly apparent reason, this seemingly pointless implementation
  // means that holding down the command key after (say) pressing ⌘C does not
  // repeat the action continuously on all subsequent reviews
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    return super.canPerformAction(action, withSender: sender)
  }

  // MARK: - TKMSubjectDelegate

  func didTap(_ subject: TKMSubject!) {
    performSegue(withIdentifier: "subjectDetails", sender: subject)
  }

  // MARK: - Keyboard navigation

  override var canBecomeFirstResponder: Bool {
    return true
  }

  override var keyCommands: [UIKeyCommand]? {
    if subjectDetailsView.isHidden {
      return [UIKeyCommand(input: "\t",
                           modifierFlags: [],
                           action: #selector(toggleFont),
                           discoverabilityTitle: "Toggle font")]
    }

    return [
      UIKeyCommand(input: "\r",
                   modifierFlags: [],
                   action: #selector(enterKeyPressed),
                   discoverabilityTitle: "Continue"),
      UIKeyCommand(input: " ",
                   modifierFlags: [],
                   action: #selector(playAudio),
                   discoverabilityTitle: "Play reading"),
      UIKeyCommand(input: "a",
                   modifierFlags: [.command],
                   action: #selector(askAgain),
                   discoverabilityTitle: "Ask again later"),
      UIKeyCommand(input: "c",
                   modifierFlags: [.command],
                   action: #selector(markCorrect),
                   discoverabilityTitle: "Mark correct"),
      UIKeyCommand(input: "s",
                   modifierFlags: [.command],
                   action: #selector(addSynonym),
                   discoverabilityTitle: "Add as synonym"),
    ]
  }

  @objc func playAudio() {
    if !subjectDetailsView.isHidden {
      subjectDetailsView.playAudio()
    }
  }
}
