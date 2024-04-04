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

import AudioToolbox
import Foundation

private let kHideShowAnimation: UITableView.RowAnimation = .fade

class TableModel: NSObject, UITableViewDataSource, UITableViewDelegate {
  struct Section {
    var hidden: Bool = false
    var headerTitle: String?
    var headerFooter: String?
    var items = [TKMModelItem]()
    var hiddenItems = NSMutableIndexSet()
  }

  var sections = [Section]()
  private var isInitialised = false
  private(set) var tableView: UITableView
  private weak var delegate: UITableViewDelegate?

  deinit {
    if !isInitialised {
      NSLog("TKMTableModel deallocated without being used. Did you forget to retain it?")
    }
  }

  init(tableView: UITableView, delegate: UITableViewDelegate?) {
    self.tableView = tableView
    self.delegate = delegate
    super.init()
    tableView.dataSource = self
    tableView.delegate = self
  }

  convenience init(tableView: UITableView) {
    self.init(tableView: tableView, delegate: nil)
  }

  var sectionCount: Int {
    sections.count
  }

  func items(inSection section: Int) -> [TKMModelItem] {
    sections[section].items
  }

  // MARK: - Hiding items

  // Adds `delta` to the section index for each hidden section above this section.
  private func translateSectionIndex(_ section: Int, delta: Int) -> Int {
    var ret = section
    for (i, s) in sections.enumerated() {
      if i > max(section, ret) {
        break
      }
      if s.hidden {
        ret += delta
      }
    }
    return ret
  }

  // Adds `delta` to the row index for each hidden row above this row.
  private func translateRowIndex(_ row: Int, section: Section, delta: Int) -> Int {
    var ret = row
    section.hiddenItems.enumerate { i, _ in
      if i <= row {
        ret += delta
      }
    }
    return ret
  }

  // Translates a UITableView index path to one that can access sections[x].items[y].
  private func modelIndexPathToViewIndexPath(_ indexPath: IndexPath) -> IndexPath {
    let section = translateSectionIndex(indexPath.section, delta: -1)
    if indexPath.count == 1 {
      return IndexPath(index: section)
    }
    return IndexPath(row: translateRowIndex(indexPath.row, section: sections[indexPath.section],
                                            delta: -1),
                     section: section)
  }

  // Translates a path in sections[x].items[y] to a UITableView index path,
  private func viewIndexPathToModelIndexPath(_ indexPath: IndexPath) -> IndexPath {
    let section = viewSectionToModelSection(indexPath.section)
    if indexPath.count == 1 {
      return IndexPath(index: section)
    }
    return IndexPath(row: translateRowIndex(indexPath.row, section: sections[section], delta: +1),
                     section: section)
  }

  // Translates a UITableView section number to one that can access sections[x].
  private func viewSectionToModelSection(_ section: Int) -> Int {
    translateSectionIndex(section, delta: +1)
  }

  // Hides or shows an item or a section.
  func setIndexPath(_ index: IndexPath, hidden: Bool) {
    if hidden == isIndexPathHidden(index) {
      return
    }

    // We need the view index path of the item in its "shown" state, which is either before hiding
    // it, or after showing it.
    let viewIndexPathBefore = modelIndexPathToViewIndexPath(index)
    
    // Update the state of the item in our model.
    if index.count == 1 {
      // The index refers to a section.
      sections[index.section].hidden = hidden
    } else {
      // The index refers to an item in a section.
      if hidden {
        sections[index.section].hiddenItems.add(index.row)
      } else {
        sections[index.section].hiddenItems.remove(index.row)
      }
    }

    // Get the view index path again.
    let viewIndexPathAfter = modelIndexPathToViewIndexPath(index)

    if !isInitialised {
      return
    }

    if index.count == 1 {
      // The index refers to a section.
      if hidden {
        tableView.deleteSections([viewIndexPathBefore.section], with: kHideShowAnimation)
      } else {
        tableView.insertSections([viewIndexPathAfter.section], with: kHideShowAnimation)
      }
    } else {
      // The index refers to an item in a section.
      if hidden {
        tableView.deleteRows(at: [viewIndexPathBefore], with: kHideShowAnimation)
      } else {
        tableView.insertRows(at: [viewIndexPathAfter], with: kHideShowAnimation)
      }
    }
  }

  func isIndexPathHidden(_ index: IndexPath) -> Bool {
    if index.count == 1 {
      return sections[index.section].hidden
    }
    return sections[index.section].hiddenItems.contains(index.row)
  }

  // MARK: - UITableViewDataSource

  func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let modelIndexPath = viewIndexPathToModelIndexPath(indexPath)
    let section = sections[modelIndexPath.section]
    return cell(item: section.items[modelIndexPath.row])
  }

  private func cell(item: TKMModelItem) -> UITableViewCell {
    var reuseId: String
    if item.responds(to: #selector(TKMModelItem.cellReuseIdentifier)) {
      reuseId = item.cellReuseIdentifier!()
    } else {
      reuseId = String(describing: item.self)
    }

    var cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as? TKMModelCell
    if cell == nil {
      if item.responds(to: #selector(TKMModelItem.createCell)) {
        cell = item.createCell!()
      } else if item.responds(to: #selector(TKMModelItem.cellNibName)) {
        let nib = UINib(nibName: item.cellNibName!(), bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: reuseId)
        cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as? TKMModelCell
      } else if item.responds(to: #selector(TKMModelItem.cellClass)) {
        let cellClass = item.cellClass!() as! UITableViewCell.Type
        cell = cellClass.init(style: .default, reuseIdentifier: reuseId) as? TKMModelCell
      }
    }
    guard let cell = cell else {
      fatalError("Item class \(reuseId) should respond to either createCell, cellNibName or cellClass")
    }

    // Disable animations when reusing a cell.
    CATransaction.begin()
    CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
    cell.update(with: item, tableView: tableView)
    CATransaction.commit()
    return cell
  }

  func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
    sections[viewSectionToModelSection(section)].headerTitle
  }

  func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
    sections[viewSectionToModelSection(section)].headerFooter
  }

  func numberOfSections(in _: UITableView) -> Int {
    isInitialised = true
    return sections.reduce(0) { count, section in
      count + (section.hidden ? 0 : 1)
    }
  }

  func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    let s = sections[viewSectionToModelSection(section)]
    return s.items.count - s.hiddenItems.count
  }

  // MARK: - UITableViewDelegate

  func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    if (tableView.cellForRow(at: indexPath) as? TKMListSeparatorCell) != nil {
      return nil
    }
    return indexPath
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let cell = tableView.cellForRow(at: indexPath) as? TKMModelCell {
      cell.didSelect()
    }
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let modelIndexPath = viewIndexPathToModelIndexPath(indexPath)
    let item = sections[modelIndexPath.section].items[modelIndexPath.item]
    if item.responds(to: #selector(TKMModelItem.rowHeight)) {
      return item.rowHeight!()
    }
    return tableView.rowHeight
  }

  func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    let section = sections[viewSectionToModelSection(section)]
    if (section.headerTitle ?? "").isEmpty {
      return 12
    }
    return tableView.sectionHeaderHeight
  }

  override func responds(to aSelector: Selector!) -> Bool {
    if let delegate = delegate, delegate.responds(to: aSelector) {
      return true
    }
    return super.responds(to: aSelector)
  }

  override func forwardingTarget(for aSelector: Selector!) -> Any? {
    if let delegate = delegate, delegate.responds(to: aSelector) {
      return delegate
    }
    return super.forwardingTarget(for: aSelector)
  }
}

class MutableTableModel: TableModel {
  @discardableResult func add(section: String?, footer: String? = nil) -> IndexPath {
    var s = Section()
    s.headerTitle = section
    s.headerFooter = footer

    let index = sections.count
    sections.append(s)
    return IndexPath(index: index)
  }

  @discardableResult func addSection() -> IndexPath {
    add(section: nil, footer: nil)
  }

  @discardableResult func add(_ item: TKMModelItem, toSection sectionIndex: Int,
                              hidden: Bool = false) -> IndexPath {
    sections[sectionIndex].items.append(item)

    let path = IndexPath(row: sections[sectionIndex].items.count - 1, section: sectionIndex)
    if hidden {
      setIndexPath(path, hidden: true)
    }
    return path
  }

  @discardableResult func add(_ item: TKMModelItem, hidden: Bool = false) -> IndexPath {
    if sections.isEmpty {
      _ = addSection()
    }
    return add(item, toSection: sections.count - 1, hidden: hidden)
  }

  @discardableResult func insert(_ item: TKMModelItem, atIndex index: Int,
                                 inSection section: Int) -> IndexPath {
    sections[section].items.insert(item, at: index)
    return IndexPath(row: index, section: section)
  }

  func sort<T>(section: Int, using fn: (T, T) -> Bool) {
    sections[section].items.sort(by: { a, b -> Bool in
      fn(a as! T, b as! T)
    })
  }

  func reloadTable() {
    tableView.reloadData()
  }
}
