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

@objc class SRSStageCategoryItem: TKMBasicModelItem {
  let stageCategory: SRSStageCategory

  @objc init(stageCategory: SRSStageCategory, count: Int) {
    self.stageCategory = stageCategory
    super.init(style: .value1,
               title: stageCategory.description,
               subtitle: String(count),
               accessoryType: .none,
               target: nil,
               action: nil)

    var color = TKMStyle.color(forSRSStageCategory: stageCategory)

    if #available(iOS 13.0, *), stageCategory == .burned,
      UITraitCollection.current.userInterfaceStyle == .dark {
      color = UIColor.label
    }
    textColor = color
    imageTintColor = color
    image = UIImage(named: stageCategory.description)!
  }
}
