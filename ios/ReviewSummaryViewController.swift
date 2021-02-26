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

class ReviewSummaryViewController: UITableViewController, SubjectDelegate {
  private var services: TKMServices!
  private var model: TKMTableModel!

  func setup(services: TKMServices, items: [ReviewItem]) {
    self.services = services

    let currentLevel = services.localCachingClient.getUserInfo()!.level
    var incorrectItemsByLevel = [Int32: [ReviewItem]]()
    var correct = 0
    for item in items {
      if !item.answer.meaningWrong, !item.answer.readingWrong {
        correct += 1
        continue
      }
      incorrectItemsByLevel[item.assignment.level, default: []].append(item)
    }

    let model = TKMMutableTableModel(tableView: tableView)

    // Summary section.
    var summaryText: String
    if items.isEmpty {
      summaryText = "0%"
    } else {
      summaryText =
        "\(Int(Double(correct) / Double(items.count) * 100.0))% (\(correct)/\(items.count))"
    }
    model.addSection("Summary")
    model.add(TKMBasicModelItem(style: .value1, title: "Correct answers", subtitle: summaryText))

    // Add a section for each level.
    let incorrectItemLevels = incorrectItemsByLevel.keys.sorted { (a, b) -> Bool in
      b < a
    }
    for level in incorrectItemLevels {
      if level == currentLevel {
        model.addSection("Current level (\(level))")
      } else {
        model.addSection("Level \(level)")
      }

      for item in incorrectItemsByLevel[level]! {
        if let subject = services.localCachingClient.getSubject(id: item.assignment.subjectID) {
          model.add(SubjectModelItem(subject: subject, delegate: self, assignment: nil,
                                     readingWrong: item.answer.readingWrong,
                                     meaningWrong: item.answer.meaningWrong))
        }
      }
    }
    self.model = model
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  @IBAction private func doneClicked() {
    navigationController?.popToRootViewController(animated: true)
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    if let vc = storyboard?
      .instantiateViewController(withIdentifier: "subjectDetailsViewController") as? SubjectDetailsViewController {
      vc.setup(services: services, subject: subject, showHints: false, hideBackButton: false,
               index: 0)
      navigationController?.pushViewController(vc, animated: true)
    }
  }
}
