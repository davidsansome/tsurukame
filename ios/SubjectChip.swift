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

protocol SubjectChipDelegate: NSObject {
  func didTapSubjectChip(_ subjectChip: SubjectChip)
}

class SubjectChip: UIView {
  let subject: TKMSubject?

  var isDimmed: Bool {
    get {
      (gradientView?.alpha ?? 0.0) < 0.75
    }
    set {
      gradientView?.alpha = newValue ? 0.5 : 1.0
    }
  }

  private weak var delegate: SubjectChipDelegate?
  private weak var gradientView: UIView?
  private weak var gradientLayer: CAGradientLayer?

  convenience init(subject: TKMSubject, showMeaning: Bool, delegate: SubjectChipDelegate) {
    let japaneseText = subject.japaneseText(imageSize: kLabelHeight)
    let sideText = showMeaning ? NSAttributedString(string: subject.primaryMeaning) : nil
    self.init(subject: subject, chipText: japaneseText, sideText: sideText, chipTextColor: .white,
              chipGradient: TKMStyle.gradient(forSubject: subject), delegate: delegate)
  }

  init(subject: TKMSubject?, chipText: NSAttributedString, sideText: NSAttributedString?,
       chipTextColor: UIColor,
       chipGradient: [Any], delegate: SubjectChipDelegate) {
    let chipFont = TKMStyle.japaneseFont(size: kLabelHeight)
    let chipLabelFrame = CGRect(x: kLabelInset, y: kLabelInset,
                                width: textWidth(text: chipText, font: chipFont),
                                height: kLabelHeight)
    let chipGradientFrame = CGRect(x: 0, y: 0, width: chipLabelFrame.maxX + kLabelInset,
                                   height: chipLabelFrame.maxY + kLabelInset)

    let chipLabel = UILabel(frame: chipLabelFrame)
    chipLabel.baselineAdjustment = .alignCenters
    chipLabel.attributedText = chipText
    chipLabel.font = chipFont
    chipLabel.textColor = chipTextColor
    chipLabel.isUserInteractionEnabled = false
    chipLabel.textAlignment = .center

    let gradientView = UIView(frame: chipGradientFrame)
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = gradientView.bounds
    gradientLayer.cornerRadius = kChipCornerRadius
    gradientLayer.masksToBounds = true
    gradientLayer.colors = chipGradient
    gradientView.layer.insertSublayer(gradientLayer, at: 0)
    self.gradientView = gradientView
    self.gradientLayer = gradientLayer

    var totalFrame = chipGradientFrame

    var sideTextLabel: UILabel?
    if let sideText = sideText {
      let sideTextFont = UIFont.systemFont(ofSize: 14.0)
      let sideTextFrame = CGRect(x: chipGradientFrame.maxX + kChipHorizontalSpacing, y: 0,
                                 width: textWidth(text: sideText, font: sideTextFont) +
                                   kChipHorizontalSpacing,
                                 height: kChipHeight)
      sideTextLabel = UILabel(frame: sideTextFrame)
      sideTextLabel!.font = sideTextFont
      sideTextLabel!.baselineAdjustment = .alignCenters
      sideTextLabel!.attributedText = sideText
      sideTextLabel!.isUserInteractionEnabled = false

      totalFrame = totalFrame.union(sideTextFrame)
    }

    self.subject = subject
    self.delegate = delegate
    super.init(frame: totalFrame)

    addSubview(gradientView)
    addSubview(chipLabel)
    if let sideTextLabel = sideTextLabel {
      addSubview(sideTextLabel)
    }

    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc func handleTap(gestureRecogniser _: UIGestureRecognizer) {
    delegate?.didTapSubjectChip(self)
  }

  // MARK: - UITraitEnvironment

  override func traitCollectionDidChange(_: UITraitCollection?) {
    if let subject = subject {
      gradientLayer?.colors = TKMStyle.gradient(forSubject: subject)
    }
  }
}

private let kChipHeight: CGFloat = 28.0
private let kLabelInset: CGFloat = 6.0
private let kLabelHeight: CGFloat = kChipHeight - kLabelInset * 2.0
private let kChipCornerRadius: CGFloat = 6.0

private let kChipHorizontalSpacing: CGFloat = 8.0

let kSubjectChipCollectionEdgeInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0,
                                                    right: 16.0)
private let kChipVerticalSpacing: CGFloat = 3.0

private func textWidth(text: NSAttributedString, font: UIFont) -> CGFloat {
  let str = NSMutableAttributedString(attributedString: text)
  str.addAttribute(.font, value: font, range: NSRange(location: 0, length: str.length))
  let rect = str
    .boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: kLabelHeight),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
  return max(kLabelHeight, rect.size.width)
}

private func alignChipFrames(_ chipFrames: inout [CGRect], width: CGFloat,
                             unalignedFrameIndex: inout Int, alignment: NSTextAlignment) {
  if alignment != .center {
    return
  }

  let totalWidth = width - kSubjectChipCollectionEdgeInsets.left * 2
  let chipTotalWidth = chipFrames.last!.maxX - kSubjectChipCollectionEdgeInsets.left
  let offset = (totalWidth - chipTotalWidth) / 2

  for i in unalignedFrameIndex ..< chipFrames.count {
    var rect = chipFrames[i]
    rect.origin.x += offset
    chipFrames[i] = rect
  }
  unalignedFrameIndex = chipFrames.count
}

func calculateSubjectChipFrames(chips: [SubjectChip], width: CGFloat,
                                alignment: NSTextAlignment) -> [CGRect] {
  var chipFrames = [CGRect]()
  var unalignedFrameIndex = 0

  var origin = CGPoint(x: kSubjectChipCollectionEdgeInsets.left,
                       y: kSubjectChipCollectionEdgeInsets.top)
  for chip in chips {
    var chipFrame = chip.frame
    chipFrame.origin = origin

    if chipFrame.maxX > width - kSubjectChipCollectionEdgeInsets.right {
      alignChipFrames(&chipFrames, width: width, unalignedFrameIndex: &unalignedFrameIndex,
                      alignment: alignment)
      chipFrame.origin.y += chipFrame.size.height + kChipVerticalSpacing
      chipFrame.origin.x = kSubjectChipCollectionEdgeInsets.left
    }

    chipFrames.append(chipFrame)
    origin = CGPoint(x: chipFrame.maxX + kChipHorizontalSpacing, y: chipFrame.origin.y)
  }
  alignChipFrames(&chipFrames, width: width, unalignedFrameIndex: &unalignedFrameIndex,
                  alignment: alignment)
  return chipFrames
}
