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

class SubjectDetailsViewController: UIViewController, SubjectDelegate, TKMViewController {
  private var services: TKMServices!
  private var showHints: Bool!
  private var hideBackButton: Bool!
  private var subject: TKMSubject!
  private var gradientLayer: CAGradientLayer?

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

  func canSwipeToGoBack() -> Bool {
    true
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    subjectDetailsView.setup(services: services, delegate: self)

    let studyMaterials = services.localCachingClient.getStudyMaterial(subjectId: subject.id)
    let assignment = services.localCachingClient.getAssignment(subjectId: subject.id)
    subjectDetailsView.update(withSubject: subject, studyMaterials: studyMaterials,
                              assignment: assignment, task: nil)

    subjectTitle.font = TKMStyle.japaneseFont(size: subjectTitle.font.pointSize)
    subjectTitle.attributedText = subject.japaneseText(imageSize: 40.0)
    gradientLayer = CAGradientLayer()
    gradientLayer!.colors = TKMStyle.gradient(forSubject: subject)
    view.layer.insertSublayer(gradientLayer!, at: 0)

    if hideBackButton {
      backButton.isHidden = true
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidAppear(animated)
    subjectDetailsView.deselectLastSubjectChipTapped()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    gradientLayer?.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width,
                                  height: subjectTitle.frame.origin.y + subjectTitle.frame.size
                                    .height)
  }

  @IBAction func backButtonPressed(sender _: UIButton) {
    navigationController?.popViewController(animated: true)
  }

  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    let vc = storyboard?
      .instantiateViewController(withIdentifier: "subjectDetailsViewController") as! SubjectDetailsViewController
    vc.setup(services: services, subject: subject)
    navigationController?.pushViewController(vc, animated: true)
  }

  // MARK: - Keyboard navigation

  override var canBecomeFirstResponder: Bool { true }
  override var keyCommands: [UIKeyCommand]? {
    [
      UIKeyCommand(input: " ",
                   modifierFlags: [],
                   action: #selector(playAudio),
                   discoverabilityTitle: "Play reading"),
      UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                   modifierFlags: [],
                   action: #selector(backButtonPressed),
                   discoverabilityTitle: "Back"),
    ]
  }

  @objc func playAudio() {
    subjectDetailsView.playAudio()
  }
}
