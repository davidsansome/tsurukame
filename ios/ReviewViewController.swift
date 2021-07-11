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
protocol ReviewViewControllerDelegate {
  func reviewViewControllerAllowsCheats(forReviewItem item: ReviewItem) -> Bool
  func reviewViewControllerAllowsCustomFonts() -> Bool
  func reviewViewControllerShowsSuccessRate() -> Bool
  func reviewViewControllerFinishedAllReviewItems(_ reviewViewController: ReviewViewController)
  @objc optional func reviewViewController(_ reviewViewController: ReviewViewController,
                                           tappedMenuButton menuButton: UIButton)
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

  private var activeQueue = [ReviewItem]()
  private var reviewQueue = [ReviewItem]()
  private var completedReviews = [ReviewItem]()
  private var activeQueueSize = 1

  private var activeTaskIndex = 0 // An index into activeQueue.
  private var activeTaskType: TaskType!
  private var activeTask: ReviewItem!
  private var activeSubject: TKMSubject!
  private var activeStudyMaterials: TKMStudyMaterials?
  private var activeAssignment: TKMAssignment?

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
  private var availableFonts: [String]?
  private var defaultFontSize: Double!

  @IBOutlet private var menuButton: UIButton!
  @IBOutlet private var questionBackground: TKMGradientView!
  @IBOutlet private var promptBackground: TKMGradientView!
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

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    kanaInput = TKMKanaInput(delegate: self)
  }

  @objc public func setup(services: TKMServices,
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
      activeQueueSize = Int(Settings.reviewBatchSize)
    }

    reviewQueue.shuffle()
    switch Settings.reviewOrder {
    case .ascendingSRSStage:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.srsStage < b.assignment.srsStage { return true }
        if a.assignment.srsStage > b.assignment.srsStage { return false }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case .descendingSRSStage:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.srsStage < b.assignment.srsStage { return false }
        if a.assignment.srsStage > b.assignment.srsStage { return true }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case .currentLevelFirst:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.level < b.assignment.level { return false }
        if a.assignment.level > b.assignment.level { return true }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case .lowestLevelFirst:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.level < b.assignment.level { return true }
        if a.assignment.level > b.assignment.level { return false }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case .newestAvailableFirst:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.availableAt < b.assignment.availableAt { return false }
        if a.assignment.availableAt > b.assignment.availableAt { return true }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case .oldestAvailableFirst:
      reviewQueue.sort { (a, b: ReviewItem) -> Bool in
        if a.assignment.availableAt < b.assignment.availableAt { return true }
        if a.assignment.availableAt > b.assignment.availableAt { return false }
        if a.assignment.subjectType.rawValue < b.assignment.subjectType.rawValue { return true }
        if a.assignment.subjectType.rawValue > b.assignment.subjectType.rawValue { return false }
        return false
      }
    case .random:
      break

    @unknown default:
      fatalError()
    }

    refillActiveQueue()
  }

  @objc public var activeQueueLength: Int {
    activeQueue.count
  }

  // MARK: - UIViewController

  override func viewDidLoad() {
    super.viewDidLoad()

    TKMStyle.addShadowToView(questionLabel, offset: 1, opacity: 0.2, radius: 4)
    TKMStyle.addShadowToView(previousSubjectButton, offset: 0, opacity: 0.7, radius: 4)

    wrapUpIcon.image = UIImage(named: "baseline_access_time_black_24pt")?
      .withRenderingMode(UIImage.RenderingMode.alwaysTemplate)

    previousSubjectGradient = CAGradientLayer()
    previousSubjectGradient.cornerRadius = 4.0
    previousSubjectButton.layer.addSublayer(previousSubjectGradient)

    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                           name: UIResponder.keyboardWillShowNotification,
                                           object: nil)

    subjectDetailsView.setup(services: services, delegate: self)

    answerField.autocapitalizationType = .none
    answerField.delegate = kanaInput
    answerField
      .addTarget(self, action: #selector(answerFieldValueDidChange),
                 for: UIControl.Event.editingChanged)

    let showSuccessRate = delegate.reviewViewControllerShowsSuccessRate()
    successRateIcon.isHidden = !showSuccessRate
    successRateLabel.isHidden = !showSuccessRate

    if !showMenuButton {
      menuButton.isHidden = true
    }

    normalFontName = TKMStyle.japaneseFontName
    currentFontName = normalFontName
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

    // Fix the extra inset at the top of the subject details view.
    subjectDetailsView
      .contentInset = UIEdgeInsets(top: -view.tkm_safeAreaInsets.top, left: 0, bottom: 0, right: 0)
  }

  override func viewWillAppear(_ animated: Bool) {
    if activeTask == nil {
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

  @objc private func keyboardWillShow(notification: NSNotification) {
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
      vc.setup(services: services, items: completedReviews)
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
    TKMStyle.withTraitCollection(traitCollection) {
      if activeQueue.count == 0 {
        delegate.reviewViewControllerFinishedAllReviewItems(self)
        return
      }

      // Update the progress labels.
      var successRateText: String
      if tasksAnswered == 0 {
        successRateText = "100%"
      } else {
        successRateText =
          String(Int(Double(tasksAnsweredCorrectly) / Double(tasksAnswered) * 100)) +
          "%"
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
      activeSubject = services.localCachingClient.getSubject(id: activeTask.assignment.subjectID)!
      activeStudyMaterials =
        services.localCachingClient
          .getStudyMaterial(subjectId: activeTask.assignment.subjectID)
      activeAssignment =
        services.localCachingClient.getAssignment(subjectId: activeTask.assignment.subjectID)

      // Choose whether to ask the meaning or the reading.
      if activeTask.answeredMeaning {
        activeTaskType = .reading
      } else if activeTask.answeredReading || activeSubject.hasRadical {
        activeTaskType = .meaning
      } else if Settings.groupMeaningReading {
        activeTaskType = Settings.meaningFirst ? .meaning : .reading
      } else {
        activeTaskType = TaskType.random()
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
      default:
        fatalError()
      }
      switch activeTaskType! {
      case .meaning:
        kanaInput.enabled = false
        taskTypePrompt = activeTask.assignment.subjectType == .radical ? "Name" : "Meaning"
        promptGradient = TKMStyle.meaningGradient as! [CGColor]
        promptTextColor = kMeaningTextColor
        taskTypePlaceholder = "Your Response"
      case .reading:
        kanaInput.enabled = true
        taskTypePrompt = "Reading"
        promptGradient = TKMStyle.readingGradient as! [CGColor]
        promptTextColor = kReadingTextColor
        taskTypePlaceholder = "答え"
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

      if Settings.allowSkippingReviews {
        // Change the skip button icon.
        submitButton.setImage(skipImage, for: .normal)
      } else {
        submitButton.isEnabled = false
      }

      // Background gradients.
      questionBackground
        .animateColors(to: TKMStyle.gradient(forAssignment: activeTask.assignment),
                       duration: animationDuration)
      promptBackground.animateColors(to: promptGradient, duration: animationDuration)

      // Accessibility.
      successRateLabel.accessibilityLabel = successRateText + " correct so far"
      doneLabel.accessibilityLabel = doneText + " done"
      queueLabel.accessibilityLabel = queueText + " remaining"
      questionLabel.accessibilityLabel = "Japanese " + subjectTypePrompt + ". Question"
      levelLabel.accessibilityLabel = "srs level \(activeTask.assignment.srsStage)"

      answerField.text = nil
      answerField.textColor = TKMStyle.Color.label
      answerField.backgroundColor = TKMStyle.Color.background
      answerField.placeholder = taskTypePlaceholder
      if let firstReading = activeSubject.primaryReadings.first {
        kanaInput.alphabet = (firstReading.hasType && firstReading.type == .onyomi &&
          Settings.useKatakanaForOnyomi) ? .katakana : .hiragana
      } else {
        kanaInput.alphabet = .hiragana
      }

      answerField.useJapaneseKeyboard = Settings
        .autoSwitchKeyboard && activeTaskType == .reading

      if Settings.showSRSLevelIndicator {
        levelLabel.attributedText = getDots(stage: activeTask.assignment.srsStage)
      } else {
        levelLabel.attributedText = nil
      }

      let setupContextFunc = {
        (ctx: AnimationContext) in
        if !(self.questionLabel.attributedText?
          .isEqual(to: self.activeSubject.japaneseText) ?? false) ||
          self.questionLabel.font.familyName != self.currentFontName {
          ctx.addFadingLabel(original: self.questionLabel!)
          self.questionLabel
            .font = UIFont(name: self.currentFontName, size: self.questionLabelFontSize())
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
  }

  // MARK: - Random fonts

  func fontsThatCanRenderText(_ text: String, exclude: [String]?) -> [String] {
    var availableFonts: [String] = []

    for filename in Settings.selectedFonts {
      if let font = services.fontLoader.font(byName: filename) {
        if let ex = exclude, ex.contains(font.fontName) {
          continue
        }
        if TKMFontCanRenderText(font.fontName, text) {
          availableFonts.append(font.fontName)
        }
      }
    }

    return availableFonts
  }

  func nextCustomFont(thatCanRenderText _: String) -> String? {
    if let availableFonts = self.availableFonts,
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
    if let availableFonts = self.availableFonts,
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
    if delegate.reviewViewControllerAllowsCustomFonts() {
      // Re-set the supported fonts when we pick a random one as that is the first
      // step.
      availableFonts = fontsThatCanRenderText(text, exclude: nil).sorted()
      return availableFonts?.randomElement() ?? normalFontName
    } else {
      return normalFontName
    }
  }

  // MARK: - Animation

  private func animateSubjectDetailsView(shown: Bool,
                                         setupContextFunc: ((AnimationContext) -> Void)?) {
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
    let submitButtonImage = shown ? forwardArrowImage :
      (Settings.allowSkippingReviews ? skipImage : tickImage)
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

    // Change the foreground color of the answer field.
    answerField.textColor = shown ? UIColor.systemRed : TKMStyle.Color.label

    // Scroll to the top.
    subjectDetailsView
      .setContentOffset(CGPoint(x: 0, y: -subjectDetailsView.contentInset.top), animated: false)

    UIView.commitAnimations()
  }

  @objc func animationDidStop(animationID _: NSString,
                              finished _: NSNumber,
                              context: UnsafeMutableRawPointer) {
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
      answerField.becomeFirstResponder()
    }
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
      newGradient = (TKMStyle.gradient(forSubject: previousSubject) as! [CGColor])
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
    let fontName = useCustomFont ? currentFontName! : normalFontName!
    questionLabel.font = UIFont(name: fontName, size: questionLabelFontSize())
  }

  @objc func didShortPressQuestionLabel(_: UITapGestureRecognizer) {
    toggleFont()
  }

  @objc func didSwipeQuestionLabel(_ sender: UISwipeGestureRecognizer) {
    if sender.direction == .left {
      showNextCustomFont()
    } else if sender.direction == .right {
      showPreviousCustomFont()
    }
  }

  @objc func showNextCustomFont() {
    currentFontName = nextCustomFont(thatCanRenderText: activeSubject.japanese) ?? normalFontName
    setCustomQuestionLabelFont(useCustomFont: true)
  }

  @objc func showPreviousCustomFont() {
    currentFontName = previousCustomFont(thatCanRenderText: activeSubject.japanese) ??
      normalFontName
    setCustomQuestionLabelFont(useCustomFont: true)
  }

  func questionLabelFontSize() -> CGFloat {
    if UI_USER_INTERFACE_IDIOM() == .pad {
      return CGFloat(defaultFontSize * 2.5 * Double(Settings.fontSize))
    } else {
      return CGFloat(defaultFontSize * Double(Settings.fontSize))
    }
  }

  @objc func toggleFont() {
    let useCustomFont =
      questionLabel.font.familyName == TKMStyle
        .japaneseFontLight(size: questionLabel.font.pointSize).familyName
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
    let text = answerField.text!.trimmingCharacters(in: .whitespaces)

    if Settings.allowSkippingReviews {
      let newImage = text.isEmpty ? skipImage : tickImage
      UIView
        .transition(with: submitButton, duration: 0.1,
                    options: .transitionCrossDissolve, animations: {
                      self.submitButton.setImage(newImage, for: .normal)
                    }, completion: nil)
    } else {
      submitButton.isEnabled = !text.isEmpty
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

    // Keep the cursor in the text field on OtherKanjiReading or ContainsInvalidCharacters
    // AnswerCheckerResult cases except when subject details are displayed.
    if subjectDetailsView.isHidden,
       activeTask.answer.hasMeaningWrong || activeTask.answer.hasReadingWrong {
      return false
    }

    return true
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
    if !answerField.isEnabled {
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
    answerField.text = AnswerChecker.normalizedString(answerField.text ?? "",
                                                      taskType: activeTaskType,
                                                      alphabet: kanaInput.alphabet)
    let result = AnswerChecker.checkAnswer(answerField.text!,
                                           subject: activeSubject,
                                           studyMaterials: activeStudyMaterials,
                                           taskType: activeTaskType,
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
        (lastMarkAnswerWasFirstTime && result == .OverrideAnswerCorrect) {
        activeTask.answer.meaningWrong = !correct
        if result == .OverrideAnswerCorrect {
          activeTask.answer.meaningWrongCount -= 1
        }
      }
      activeTask.answeredMeaning = correct

      if !correct {
        activeTask.answer.meaningWrongCount += 1
      }

    case .reading:
      firstTimeAnswered = !activeTask.answer.hasReadingWrong
      if firstTimeAnswered ||
        (lastMarkAnswerWasFirstTime && result == .OverrideAnswerCorrect) {
        activeTask.answer.readingWrong = !correct
        if result == .OverrideAnswerCorrect {
          activeTask.answer.readingWrongCount -= 1
        }
      }
      activeTask.answeredReading = correct

      if !correct {
        activeTask.answer.readingWrongCount += 1
      }

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
      didLevelUp ? activeTask.assignment.srsStage.next : activeTask.assignment.srsStage.previous
    if isSubjectFinished {
      let date = Int32(Date().timeIntervalSince1970)
      if date > activeTask.assignment.availableAt {
        activeTask.answer.createdAt = date
      }

      if Settings.minimizeReviewPenalty {
        if activeTask.answer.meaningWrong {
          activeTask.answer.meaningWrongCount = 1
        }
        if activeTask.answer.readingWrong {
          activeTask.answer.readingWrongCount = 1
        }
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
         activeSubject.hasVocabulary, !activeSubject.vocabulary.audioIds.isEmpty {
        services.audio.play(subjectID: activeSubject!.id, delegate: nil)
      }

      var previousSubjectLabel: UILabel?
      if isSubjectFinished, showSubjectHistory {
        previousSubjectLabel = copyLabel(questionLabel)
        previousSubject = activeSubject
      }
      randomTask()
      if correct {
        // We must start the success animations *after* all the UI elements have been moved to their
        // new locations by randomTask(), so that, for example, the success sparkles animate from
        // the final position of the answerField, not the original position.
        RunSuccessAnimation(answerField, doneLabel, levelLabel, isSubjectFinished, didLevelUp,
                            newSrsStage.rawValue)
      }

      if let previousSubjectLabel = previousSubjectLabel {
        animateLabelToPreviousSubjectButton(previousSubjectLabel)
      }
      return
    }

    // Otherwise show the correct answer.
    if !Settings.showAnswerImmediately {
      revealAnswerButton.isHidden = false
      UIView.animate(withDuration: animationDuration,
                     animations: {
                       self.answerField.textColor = UIColor.systemRed
                       self.answerField.isEnabled = false
                       self.revealAnswerButton.alpha = 1.0
                       self.submitButton.setImage(self.forwardArrowImage, for: .normal)
                     })
    } else {
      revealAnswerButtonPressed(revealAnswerButton!)
    }
  }

  @IBAction func revealAnswerButtonPressed(_: Any) {
    subjectDetailsView.update(withSubject: activeSubject, studyMaterials: activeStudyMaterials,
                              assignment: activeAssignment, task: activeTask)

    let setupContextFunc = { (ctx: AnimationContext) in
      if self.questionLabel.font.familyName != self.normalFontName {
        ctx.addFadingLabel(original: self.questionLabel)
        self.questionLabel
          .font = UIFont(name: self.normalFontName, size: self.questionLabelFontSize())
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
      activeStudyMaterials!.subjectID = activeSubject.id
    }
    activeStudyMaterials!.meaningSynonyms.append(answerField.text!)
    services.localCachingClient?.updateStudyMaterial(activeStudyMaterials!)
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
                                                   action: #selector(playAudio),
                                                   discoverabilityTitle: "Play reading"),
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
                                      UIKeyCommand(input: "s",
                                                   modifierFlags: [.command],
                                                   action: #selector(addSynonym),
                                                   discoverabilityTitle: "Add as synonym"),
                                      keyboardEnter,
                                      numericKeyPadEnter])
    }

    if Settings.selectedFonts.count > 0 {
      keyCommands.append(UIKeyCommand(input: "\t",
                                      modifierFlags: [],
                                      action: #selector(toggleFont),
                                      discoverabilityTitle: "Toggle font"))
      if #available(macOS 10.14, *) {
        keyCommands.append(UIKeyCommand(input: UIKeyCommand.inputRightArrow,
                                        modifierFlags: [],
                                        action: #selector(showNextCustomFont),
                                        discoverabilityTitle: "Next font"))
        keyCommands.append(UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                                        modifierFlags: [],
                                        action: #selector(showPreviousCustomFont),
                                        discoverabilityTitle: "Previous font"))
      }
    }
    if !previousSubjectButton.isHidden {
      keyCommands.append(UIKeyCommand(input: "p",
                                      modifierFlags: [.command],
                                      action: #selector(previousSubjectButtonPressed(_:)),
                                      discoverabilityTitle: "Previous subject"))
    }
    return keyCommands
  }

  @objc func playAudio() {
    if !subjectDetailsView.isHidden {
      subjectDetailsView.playAudio()
    }
  }
}
