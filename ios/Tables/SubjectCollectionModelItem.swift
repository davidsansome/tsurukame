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

class SubjectCollectionModelItem: NSObject, TKMModelItem {
  let subjects: GPBInt32Array
  let localCachingClient: LocalCachingClient
  weak var delegate: TKMSubjectChipDelegate?

  init(subjects: GPBInt32Array, localCachingClient: LocalCachingClient,
       delegate: TKMSubjectChipDelegate) {
    self.subjects = subjects
    self.localCachingClient = localCachingClient
    self.delegate = delegate
  }

  func cellClass() -> AnyClass! {
    SubjectCollectionModelView.self
  }
}

private class SubjectCollectionModelView: TKMModelCell {
  var chips = [TKMSubjectChip]()

  override func update(with item: TKMModelItem!) {
    super.update(with: item)
    guard let item = item as? SubjectCollectionModelItem else {
      return
    }

    selectionStyle = .none

    // Remove all existing chips.
    for chip in chips {
      chip.removeFromSuperview()
    }
    chips.removeAll()

    // Create a chip for each subject.
    for i in 0 ..< item.subjects.count {
      let subjectId = item.subjects.value(at: i)
      if let subject = item.localCachingClient.getSubject(id: Int(subjectId)),
        let delegate = item.delegate {
        let chip = TKMSubjectChip(subject: subject, showMeaning: true, delegate: delegate)
        contentView.addSubview(chip)
        chips.append(chip)
      }
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let frames = TKMCalculateSubjectChipFrames(chips, frame.size.width, .left)
    for (idx, frame) in frames.enumerated() {
      chips[idx].frame = frame.cgRectValue
    }
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    if chips.isEmpty {
      return size
    }
    let frames = TKMCalculateSubjectChipFrames(chips, frame.size.width, .left)
    if frames.isEmpty {
      return size
    }
    return CGSize(width: size.width,
                  height: frames.last!.cgRectValue.maxY +
                          kTKMSubjectChipCollectionEdgeInsets.bottom)
  }
}
