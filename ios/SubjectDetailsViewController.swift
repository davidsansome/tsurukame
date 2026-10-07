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
import WaniKaniAPI

class SubjectDetailsViewController: UIViewController, SubjectDelegate, TKMViewController {
  private var services: TKMServices!
  private var showHints: Bool!
  private var hideBackButton: Bool!
  private var subject: TKMSubject!
  private let hero = UIView()

  @objc private(set) var index: Int = 0

  @IBOutlet var subjectDetailsView: SubjectDetailsView!
  @IBOutlet var subjectTitle: UILabel!
  @IBOutlet var backButton: UIButton!

  func setup(services: TKMServices, subject: TKMSubject, showHints: Bool = false,
             hideBackButton: Bool = false,
             index: Int = 0) {
    self.services = services
    self.subject = subject
    self.showHints = showHints
    self.hideBackButton = hideBackButton
    self.index = index
  }

  var canSwipeToGoBack: Bool { true }

  override func viewDidLoad() {
    super.viewDidLoad()
    subjectDetailsView.setup(services: services, delegate: self)

    let studyMaterials = services.localCachingClient.getStudyMaterial(subjectId: subject.id)
    let assignment = services.localCachingClient.getAssignment(subjectId: subject.id)
    subjectDetailsView.update(withSubject: subject, studyMaterials: studyMaterials,
                              assignment: assignment, task: nil)

    setUpHero(assignment: assignment)

    if hideBackButton {
      backButton.isHidden = true
    }

    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(keyboardWillShow),
                   name: UIResponder.keyboardWillShowNotification, object: nil)
    nc.addObserver(self, selector: #selector(keyboardWillHide),
                   name: UIResponder.keyboardWillHideNotification, object: nil)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    subjectDetailsView.saveStudyMaterials()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    subjectDetailsView.deselectLastSubjectChipTapped()
  }

  // MARK: - Hero

  // The subject on a block of its colour with rounded bottom corners and waves: the characters,
  // the primary meaning, and chips for its type, level and SRS stage.
  private func setUpHero(assignment: TKMAssignment?) {
    let color = UIColor(cgColor: TKMStyle.gradient(forSubject: subject).first as! CGColor)
    hero.backgroundColor = color
    view.backgroundColor = TKMStyle.Color.background
    hero.layer.cornerRadius = 32
    hero.layer.cornerCurve = .continuous
    hero.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    hero.clipsToBounds = true
    let waves = WavesView()
    waves.waveColor = UIColor.white.withAlphaComponent(0.08)
    waves.fillColor = .clear
    waves.radius = 18

    // Subjects keep the app's Japanese font.
    subjectTitle.font = UIFont(name: TKMStyle.japaneseFontName, size: 96)
    subjectTitle.attributedText = japaneseText(subject, imageSize: 80.0)
    subjectTitle.adjustsFontSizeToFitWidth = true
    subjectTitle.minimumScaleFactor = 0.4
    for constraint in subjectTitle.constraints where constraint.firstAttribute == .height {
      constraint.constant = 120
    }

    let meaning = UILabel()
    meaning.text = subject.primaryMeaning
    meaning.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
    meaning.textColor = .white
    meaning.textAlignment = .center
    meaning.numberOfLines = 2

    var chipTexts = ["\(subjectTypeName) · Level \(subject.level)"]
    if let assignment = assignment, assignment.hasSrsStageNumber, !assignment.isLessonStage {
      chipTexts.append(assignment.srsStage.description)
    }
    let chips = UIStackView(arrangedSubviews: chipTexts.map { text in
      let chip = PillLabel()
      chip.text = text
      return chip
    })
    chips.spacing = 8

    let info = UIStackView(arrangedSubviews: [meaning, chips])
    info.axis = .vertical
    info.alignment = .center
    info.spacing = 12

    styleRoundBackButton(backButton, in: view)

    for v in [hero, waves, info] {
      v.translatesAutoresizingMaskIntoConstraints = false
    }
    view.insertSubview(hero, at: 0)
    hero.addSubview(waves)
    view.addSubview(info)

    // The table now starts below the hero rather than directly under the title.
    for constraint in view.constraints where
      (constraint.firstItem as? UIView) == subjectDetailsView && constraint
      .firstAttribute == .top {
      constraint.isActive = false
    }
    NSLayoutConstraint.activate([
      hero.topAnchor.constraint(equalTo: view.topAnchor),
      hero.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hero.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hero.bottomAnchor.constraint(equalTo: info.bottomAnchor, constant: 28),
      waves.leadingAnchor.constraint(equalTo: hero.leadingAnchor),
      waves.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
      waves.bottomAnchor.constraint(equalTo: hero.bottomAnchor),
      waves.heightAnchor.constraint(equalToConstant: 110),
      info.topAnchor.constraint(equalTo: subjectTitle.bottomAnchor, constant: 4),
      info.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      info.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      subjectDetailsView.topAnchor.constraint(equalTo: hero.bottomAnchor, constant: 4),
    ])
  }

  private var subjectTypeName: String {
    switch subject.subjectType {
    case .radical: return "Radical"
    case .kanji: return "Kanji"
    case .vocabulary: return "Vocabulary"
    default: return ""
    }
  }

  @IBAction func backButtonPressed(sender _: UIButton) {
    navigationController?.popViewController(animated: true)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  @objc private func keyboardWillShow(notification: NSNotification) {
    guard let keyboardSize = notification
      .userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
      return
    }
    subjectDetailsView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height,
                                                   right: 0)
  }

  @objc private func keyboardWillHide(notification _: NSNotification) {
    subjectDetailsView.contentInset = .zero
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let vc = StoryboardScene.SubjectDetails.initialScene.instantiate()
    vc.setup(services: services, subject: subject)
    navigationController?.pushViewController(vc, animated: true)
  }

  func openPracticeReview(_ subject: TKMSubject) {
    if FeatureFlags.showSubjectDeveloperOptions {
      var assignment = TKMAssignment()
      assignment.subjectType = subject.subjectType
      let item = ReviewItem(assignment: assignment, subject: subject)

      let vc = StoryboardScene.ReviewContainer.initialScene.instantiate()
      vc.setup(services: services, items: [item], isPracticeSession: true)

      navigationController?.pushViewController(vc, animated: true)
    }
  }

  // MARK: - Keyboard navigation

  override var canBecomeFirstResponder: Bool { true }
  override var keyCommands: [UIKeyCommand]? {
    [
      UIKeyCommand(input: " ",
                   modifierFlags: [],
                   action: #selector(showAllInformation),
                   discoverabilityTitle: "Show all information"),
      UIKeyCommand(input: "j",
                   modifierFlags: [],
                   action: #selector(playAudio),
                   discoverabilityTitle: "Play reading"),
      UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                   modifierFlags: [],
                   action: #selector(backButtonPressed),
                   discoverabilityTitle: "Back"),
    ]
  }

  @objc func showAllInformation() {
    subjectDetailsView.showAllFields()
  }

  @objc func playAudio() {
    subjectDetailsView.playAudio()
  }
}

// Turns a storyboard back button pinned to the top-left of the safe area into the round
// translucent button that sits over a subject's colour.
func styleRoundBackButton(_ button: UIButton, in view: UIView) {
  var config = UIButton.Configuration.filled()
  config.image = UIImage(systemName: "chevron.left",
                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 16,
                                                                        weight: .bold))
  config.baseForegroundColor = .white
  config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.16)
  config.cornerStyle = .capsule
  button.setTitle(nil, for: .normal)
  button.setImage(nil, for: .normal)
  button.configuration = config
  button.accessibilityLabel = "Back"

  // A 44pt circle, inset from the edge like the other round buttons.
  for constraint in view.constraints where
    (constraint.firstItem as? UIView) == button && constraint.firstAttribute == .leading {
    constraint.constant = 16
  }
  NSLayoutConstraint.deactivate(button.constraints.filter {
    $0.firstAttribute == .height || $0.firstAttribute == .width
  })
  NSLayoutConstraint.activate([
    button.widthAnchor.constraint(equalToConstant: 44),
    button.heightAnchor.constraint(equalToConstant: 44),
  ])
}
