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

protocol SearchResultViewControllerDelegate: NSObject {
  func searchResultSelected(subject: TKMSubject)
}

private func subjectMatchesQuery(subject: TKMSubject, query: String, kanaQuery: String) -> Bool {
  if subject.japanese.hasPrefix(query) {
    return true
  }
  for meaning in subject.meanings {
    if meaning.meaning.lowercased().hasPrefix(query) {
      return true
    }
  }
  for reading in subject.readings {
    if reading.reading.hasPrefix(kanaQuery) {
      return true
    }
  }
  return false
}

private func subjectMatchesQueryExactly(subject: TKMSubject, query: String,
                                        kanaQuery: String) -> Bool {
  for meaning in subject.meanings {
    if meaning.meaning.lowercased() == query {
      return true
    }
  }
  for reading in subject.readings {
    if reading.reading == kanaQuery {
      return true
    }
  }
  return false
}

private let kMaxResults = 50

class SearchResultViewController: UITableViewController, UISearchResultsUpdating,
  SubjectDelegate {
  private var services: TKMServices!
  private weak var delegate: SearchResultViewControllerDelegate?

  private var allSubjects: [TKMSubject]?
  private var model: TKMTableModel!
  private var queue: DispatchQueue?

  func setup(with services: TKMServices, delegate: SearchResultViewControllerDelegate) {
    self.services = services
    self.delegate = delegate
  }

  override func viewDidLoad() {
    queue = DispatchQueue(label: "tsurukame.search-results", qos: .userInitiated, attributes: [],
                          autoreleaseFrequency: .inherit,
                          target: DispatchQueue.global(qos: .userInitiated))

    queue!.async {
      self.ensureAllSubjectsLoaded()
    }
  }

  override func didReceiveMemoryWarning() {
    guard let queue = queue else {
      return
    }

    queue.sync {
      self.allSubjects = nil
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    guard let queue = queue else {
      return
    }
    super.viewWillDisappear(animated)
    queue.sync {
      self.allSubjects = nil
    }
  }

  private func ensureAllSubjectsLoaded() {
    if allSubjects == nil {
      allSubjects = services.localCachingClient.getAllSubjects()
    }
  }

  // MARK: - UISearchResultsUpdating

  func updateSearchResults(for searchController: UISearchController) {
    guard let queue = queue else {
      return
    }

    let query = searchController.searchBar.text!.lowercased()
    queue.async {
      self.ensureAllSubjectsLoaded()

      let kanaQuery = TKMConvertKanaText(query)

      var results = [TKMSubject]()
      for subject in self.allSubjects! {
        if subjectMatchesQuery(subject: subject, query: query, kanaQuery: kanaQuery) {
          results.append(subject)
        }
        if results.count > kMaxResults {
          break
        }
      }

      results.sort { (a, b) -> Bool in
        let aMatchesExactly = subjectMatchesQueryExactly(subject: a, query: query,
                                                         kanaQuery: kanaQuery)
        let bMatchesExactly = subjectMatchesQueryExactly(subject: b, query: query,
                                                         kanaQuery: kanaQuery)
        if aMatchesExactly, !bMatchesExactly {
          return true
        }
        if bMatchesExactly, !aMatchesExactly {
          return false
        }
        if a.level < b.level {
          return true
        }
        if a.level > b.level {
          return false
        }
        return false
      }

      DispatchQueue.main.async {
        // If the query text changed since we started, don't update the list.
        let newQuery = searchController.searchBar.text!.lowercased()
        if query != newQuery {
          return
        }

        let model = TKMMutableTableModel(tableView: self.tableView)
        model.addSection()
        for subject in results {
          model.add(SubjectModelItem(subject: subject, delegate: self))
        }
        self.model = model
        self.tableView.reloadData()
      }
    }
  }

  // MARK: - SubjectDelegate

  func didTapSubject(_ subject: TKMSubject) {
    delegate?.searchResultSelected(subject: subject)
  }
}
