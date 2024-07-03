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
import WaniKaniAPI

class MainPracticeTabViewController: UITableViewController {
  var services: TKMServices!
  var model: TableModel!

  func setup(services: TKMServices) {
    self.services = services
  }

  override func viewDidLoad() {
    recreateTableModel()
  }

  func update() {
    recreateTableModel()
  }

  private func recreateTableModel() {
    let model = MutableTableModel(tableView: tableView)

    model.add(section: "Katakana")

    let charactersItem = BasicModelItem(style: .default, title: "Katakana characters",
                                        accessoryType: .disclosureIndicator) {
      [unowned self] in
      self.perform(segue: StoryboardSegue.Main.katakanaCharacterPractice, sender: self)
    }
    model.add(charactersItem)

    self.model = model
    tableView.reloadData()
  }

  // MARK: - UIViewController

  override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
    switch StoryboardSegue.Main(segue) {
    case .katakanaCharacterPractice:
      var items = [ReviewItem]()
      for japanese in kAllKatakana {
        var subject = TKMSubject()
        subject.japanese = japanese
        subject.vocabulary = TKMVocabulary()

        var reading = TKMReading()
        reading.reading = japanese.applyingTransform(.hiraganaToKatakana, reverse: true)!
        subject.readings.append(reading)

        var assignment = TKMAssignment()
        assignment.subjectType = .vocabulary

        items.append(ReviewItem(assignment: assignment, subject: subject))
      }

      let vc = segue.destination as! ReviewContainerViewController
      vc.setup(services: services, items: items, isPracticeSession: true)

    default:
      break
    }
  }
}

private let kAllKatakana = [
  "ア",
  "イ",
  "ウ",
  "エ",
  "オ",
  "カ",
  "キ",
  "ク",
  "ケ",
  "コ",
  "キャ",
  "キュ",
  "キョ",
  "サ",
  "シ",
  "ス",
  "セ",
  "ソ",
  "シャ",
  "シュ",
  "ショ",
  "タ",
  "チ",
  "ツ",
  "テ",
  "ト",
  "チャ",
  "チュ",
  "チョ",
  "ナ",
  "ニ",
  "ヌ",
  "ネ",
  "ノ",
  "ニャ",
  "ニュ",
  "ニョ",
  "ハ",
  "ヒ",
  "フ",
  "ヘ",
  "ホ",
  "ヒャ",
  "ヒュ",
  "ヒョ",
  "マ",
  "ミ",
  "ム",
  "メ",
  "モ",
  "ミャ",
  "ミュ",
  "ミョ",
  "ヤ",
  "ユ",
  "エ",
  "ヨ",
  "ラ",
  "リ",
  "ル",
  "レ",
  "ロ",
  "リャ",
  "リュ",
  "リョ",
  "ワ",
  "ガ",
  "ギ",
  "グ",
  "ゲ",
  "ゴ",
  "ギャ",
  "ギュ",
  "ギョ",
  "ザ",
  "ジ",
  "ズ",
  "ゼ",
  "ゾ",
  "ジャ",
  "ジュ",
  "ジョ",
  "ダ",
  "ヂ",
  "ヅ",
  "デ",
  "ド",
  "ヂャ",
  "ヂュ",
  "ヂョ",
  "バ",
  "ビ",
  "ブ",
  "ベ",
  "ボ",
  "ビャ",
  "ビュ",
  "ビョ",
  "パ",
  "ピ",
  "プ",
  "ペ",
  "ポ",
  "ピャ",
  "ピュ",
  "ピョ",
  "ン",
]
