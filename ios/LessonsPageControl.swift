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

@objc
class LessonsPageControl: UIControl, SubjectChipDelegate {
  private var chips = [SubjectChip]()

  func setSubjects(_ subjects: [TKMSubject]) {
    // Remove all existing chips.
    for chip in chips {
      chip.removeFromSuperview()
    }
    chips.removeAll()

    // Create a chip for each subject.
    for subject in subjects {
      let chip = SubjectChip(subject: subject, showMeaning: false, delegate: self)
      addSubview(chip)
      chips.append(chip)
    }

    // Create the quiz chip.
    let quizText = NSAttributedString(string: "Quiz")
    let gradient: [Any] = [TKMStyle.Color.grey80.cgColor, TKMStyle.Color.grey80.cgColor]
    let quizChip = SubjectChip(subject: nil, chipText: quizText, sideText: nil,
                               chipTextColor: .white, chipGradient: gradient, delegate: self)
    addSubview(quizChip)
    chips.append(quizChip)

    currentPageIndexChanged()
    setNeedsLayout()
  }

  @objc
  var currentPageIndex = 0 {
    didSet { currentPageIndexChanged() }
  }

  private func currentPageIndexChanged() {
    for (idx, chip) in chips.enumerated() {
      chip.isDimmed = idx != currentPageIndex
    }
  }

  // MARK: - Layout

  override func layoutSubviews() {
    let frames = calculateSubjectChipFrames(chips: chips, width: frame.size.width,
                                            alignment: .center)
    for (idx, chip) in chips.enumerated() {
      chip.frame = frames[idx]
    }
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    if chips.isEmpty {
      return size
    }

    let frames = calculateSubjectChipFrames(chips: chips, width: frame.size.width,
                                            alignment: .center)
    return CGSize(width: size.width,
                  height: frames.last!.maxY + kSubjectChipCollectionEdgeInsets
                    .bottom)
  }

  // MARK: - SubjectChipDelegate

  func didTapSubjectChip(_ subjectChip: SubjectChip) {
    for (idx, chip) in chips.enumerated() {
      if chip == subjectChip {
        currentPageIndex = idx
        sendActions(for: .valueChanged)
        break
      }
    }
  }
}
