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

@objc(TKMSubjectModelItem)
@objcMembers
class SubjectModelItem: NSObject, TKMModelItem {
  let subject: TKMSubject
  let readingWrong: Bool
  let meaningWrong: Bool

  weak var delegate: SubjectDelegate?
  var assignment: TKMAssignment?
  var showLevelNumber = true
  var showAnswers = true
  var showRemaining = false
  var gradientColors: [Any]?

  init(subject: TKMSubject, delegate: SubjectDelegate, assignment: TKMAssignment? = nil,
       readingWrong: Bool = false, meaningWrong: Bool = false) {
    self.subject = subject
    self.delegate = delegate
    self.assignment = assignment
    self.readingWrong = readingWrong
    self.meaningWrong = meaningWrong
  }

  func cellNibName() -> String! {
    "TKMSubjectModelItem"
  }
}

private let kJapaneseTextImageSize: CGFloat = 26.0
private let kFontSize: CGFloat = 14.0

@objc(TKMSubjectModelView)
class SubjectModelView: TKMModelCell {
  private weak var gradient: CAGradientLayer?

  @IBOutlet var levelLabel: UILabel!
  @IBOutlet var subjectLabel: UILabel!
  @IBOutlet var readingLabel: UILabel!
  @IBOutlet var meaningLabel: UILabel!
  @IBOutlet var answerStack: UIStackView!

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    let gradientLayer = CAGradientLayer()
    gradient = gradientLayer
    contentView.layer.insertSublayer(gradientLayer, at: 0)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    gradient?.frame = contentView.bounds
  }

  // MARK: - TKMModelCell

  override func update(with item: TKMModelItem!) {
    super.update(with: item)
    guard let item = item as? SubjectModelItem else {
      return
    }

    levelLabel.isHidden = !item.showLevelNumber
    if item.showLevelNumber {
      levelLabel.text = "\(item.subject.level)"
    }
    updateGradient()

    subjectLabel.font = TKMStyle.japaneseFont(size: subjectLabel.font.pointSize)
    subjectLabel.attributedText = item.subject.japaneseText(imageSize: kJapaneseTextImageSize)

    if item.showRemaining {
      if let assignment = item.assignment, assignment.isReviewStage {
        readingLabel.isHidden = false
        readingLabel.text = formattedInterval(until: assignment.reviewDate!, label: "Review")
        meaningLabel.isHidden = false
        meaningLabel
          .text = formattedInterval(until: assignment.guruDate(subject: item.subject)!,
                                    label: "Guru")
      } else if let assignment = item.assignment, assignment.isLessonStage {
        readingLabel.isHidden = false
        readingLabel.text = formattedInterval(until: assignment.guruDate(subject: item.subject)!,
                                              label: "Guru")
        meaningLabel.isHidden = true
      } else {
        readingLabel.isHidden = true
        meaningLabel.isHidden = true
      }

      readingLabel.font = UIFont.systemFont(ofSize: kFontSize)
      meaningLabel.font = UIFont.systemFont(ofSize: kFontSize)
    } else {
      switch item.subject.subjectType {
      case .radical:
        readingLabel.isHidden = true
        meaningLabel.text = item.subject.commaSeparatedMeanings
      case .kanji:
        readingLabel.isHidden = false
        readingLabel.text = item.subject.commaSeparatedPrimaryReadings
        meaningLabel.text = item.subject.commaSeparatedMeanings
      case .vocabulary:
        readingLabel.isHidden = false
        readingLabel.text = item.subject.commaSeparatedReadings
        meaningLabel.text = item.subject.commaSeparatedMeanings
      default:
        break
      }
    }

    readingLabel.font = item.readingWrong ? TKMStyle.japaneseFontBold(size: kFontSize)
      : TKMStyle.japaneseFont(size: kFontSize)
    meaningLabel.font = item.meaningWrong ? UIFont.systemFont(ofSize: kFontSize, weight: .bold)
      : UIFont.systemFont(ofSize: kFontSize)
  }

  private func formattedInterval(until toDate: Date, label: String) -> String {
    if Date().compare(toDate) == .orderedDescending {
      return "\(label) available"
    }

    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated

    var components = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(),
                                                     to: toDate)

    // Only show minutes after there are no hours left.
    if components.hour ?? 0 > 0 {
      components.minute = 0
    }

    let interval = formatter.string(from: components)!
    return "\(label) in \(interval)"
  }

  @objc
  func setShowAnswers(_ value: Bool, animated: Bool) {
    if !animated {
      answerStack.isHidden = !value
      answerStack.alpha = value ? 1.0 : 0.0
      return
    }

    // Unhide the answer frame and update its width.
    answerStack.isHidden = false
    setNeedsLayout()
    layoutIfNeeded()

    let visibleFrame = answerStack.frame
    var hiddenFrame = visibleFrame
    hiddenFrame.origin.x = frame.size.width

    answerStack.frame = value ? hiddenFrame : visibleFrame
    answerStack.alpha = value ? 0.0 : 1.0

    UIView.animate(withDuration: 0.5) {
      self.answerStack.frame = value ? visibleFrame : hiddenFrame
      self.answerStack.alpha = value ? 1.0 : 0.0
    } completion: { _ in
      self.answerStack.isHidden = !value
    }
  }

  override func didSelect() {
    if let item = item as? SubjectModelItem {
      item.delegate?.didTapSubject(item.subject)
    }
  }

  // MARK: - UITraitEnvironment

  override func traitCollectionDidChange(_: UITraitCollection?) {
    updateGradient()
  }

  private func updateGradient() {
    if let item = item as? SubjectModelItem {
      if let itemGradientColors = item.gradientColors {
        gradient?.colors = itemGradientColors
      } else {
        gradient?.colors = TKMStyle.gradient(forSubject: item.subject)
      }
    }
  }
}
