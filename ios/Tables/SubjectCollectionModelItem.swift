// Copyright 2024 David Sansome
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

class SubjectCollectionModelItem: TableModelItem {
  let subjects: [Int64]
  let fontSize: CGFloat
  let localCachingClient: LocalCachingClient
  weak var delegate: SubjectChipDelegate?

  init(subjects: [Int64], fontSize: CGFloat, localCachingClient: LocalCachingClient,
       delegate: SubjectChipDelegate? = nil) {
    self.subjects = subjects
    self.fontSize = fontSize
    self.localCachingClient = localCachingClient
    self.delegate = delegate
  }

  var cellFactory: TableModelCellFactory {
    .fromDefaultConstructor(cellClass: SubjectCollectionModelView.self)
  }
}

private class SubjectCollectionModelView: TableModelCell {
  @TypedModelItem var item: SubjectCollectionModelItem

  var chips = [SubjectChip]()

  override func update() {
    selectionStyle = .none

    // Remove all existing chips.
    for chip in chips {
      chip.removeFromSuperview()
    }
    chips.removeAll()

    // Create a chip for each subject.
    for subjectId in item.subjects {
      if let subject = item.localCachingClient.getSubject(id: subjectId),
         let delegate = item.delegate {
        let chip = SubjectChip(subject: subject, showMeaning: true, meaningFontSize: item.fontSize,
                               delegate: delegate)
        contentView.addSubview(chip)
        chips.append(chip)
      }
    }
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let frames = calculateSubjectChipFrames(chips: chips, width: frame.size.width, alignment: .left)
    for (idx, frame) in frames.enumerated() {
      chips[idx].frame = frame
    }
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    if chips.isEmpty {
      return size
    }
    let frames = calculateSubjectChipFrames(chips: chips, width: frame.size.width, alignment: .left)
    if frames.isEmpty {
      return size
    }
    return CGSize(width: size.width,
                  height: frames.last!.maxY +
                    kSubjectChipCollectionEdgeInsets.bottom)
  }
}
