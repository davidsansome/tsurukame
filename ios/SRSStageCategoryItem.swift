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

@objc class SRSStageCategoryItem: TKMBasicModelItem {
  let stageCategory: TKMSRSStageCategory

  @objc init(stageCategory: TKMSRSStageCategory, count: Int) {
    self.stageCategory = stageCategory
    super.init(style: .value1,
               title: TKMSRSStageCategoryName(stageCategory),
               subtitle: String(count),
               accessoryType: .none,
               target: nil,
               action: nil)

    let color = TKMStyle.color(forSRSStageCategory: stageCategory)
    textColor = color
    imageTintColor = color
    image = UIImage(named: TKMSRSStageCategoryName(stageCategory))!
  }
}
