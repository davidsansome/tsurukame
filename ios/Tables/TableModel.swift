// Copyright 2025 David Sansome
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
    var footerTitle: String?
    var items = [any TableModelItem]()
    var hiddenItems = NSMutableIndexSet()
  }

  var sections = [Section]()
  private(set) var isInitialised = false
  private(set) unowned var tableView: UITableView
  private weak var delegate: UITableViewDelegate?

  // If set to true, the table will use the sectionHeaderHeight
  // from the UITableView instead of the UITableView.automaticDimension.
  var useSectionHeaderHeightFromView = false

  deinit {
    if !isInitialised {
      NSLog("TableModel deallocated without being used. Did you forget to retain it?")
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

  func items(inSection section: Int) -> [any TableModelItem] {
    sections[section].items
  }

  func item(inSection section: Int, atRow row: Int) -> any TableModelItem {
    sections[section].items[row]
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
      if (delta < 0 && i <= row) || (delta > 0 && i <= ret) {
        ret += delta
      }
    }
    return ret
  }

  // Translates a UITableView index path to one that can access sections[x].items[y].
  func modelIndexPathToViewIndexPath(_ indexPath: IndexPath) -> IndexPath {
    let section = translateSectionIndex(indexPath.section, delta: -1)
    if indexPath.count == 1 {
      return IndexPath(index: section)
    }
    return IndexPath(row: translateRowIndex(indexPath.row, section: sections[indexPath.section],
                                            delta: -1),
                     section: section)
  }

  // Translates a path in sections[x].items[y] to a UITableView index path,
  func viewIndexPathToModelIndexPath(_ indexPath: IndexPath) -> IndexPath {
    let section = viewSectionToModelSection(indexPath.section)
    if indexPath.count == 1 {
      return IndexPath(index: section)
    }
    return IndexPath(row: translateRowIndex(indexPath.row, section: sections[section], delta: +1),
                     section: section)
  }

  // Translates a UITableView section number to one that can access sections[x].
  func viewSectionToModelSection(_ section: Int) -> Int {
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

  private func cell(item: any TableModelItem) -> UITableViewCell {
    let reuseId = item.cellReuseIdentifier

    var cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as? TableModelCell
    if cell == nil {
      switch item.cellFactory {
      case let .fromInterfaceBuilder(nibName):
        let nib = UINib(nibName: nibName, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: reuseId)
        cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as? TableModelCell
      case let .fromFunction(function):
        cell = function()
      case let .fromDefaultConstructor(cellClass):
        cell = cellClass.init(style: .default, reuseIdentifier: reuseId) as? TableModelCell
      }
    }
    guard let cell = cell else {
      fatalError("Item class \(reuseId)'s cellFactory returned nil")
    }

    // Disable animations when reusing a cell.
    CATransaction.begin()
    CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
    cell.baseItem = item
    cell.tableView = tableView
    cell.update()
    CATransaction.commit()
    return cell
  }

  func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
    sections[viewSectionToModelSection(section)].headerTitle
  }

  func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
    sections[viewSectionToModelSection(section)].footerTitle
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
    if (tableView.cellForRow(at: indexPath) as? ListSeparatorCell) != nil {
      return nil
    }
    return indexPath
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let cell = tableView.cellForRow(at: indexPath) as? TableModelCell {
      cell.didSelect()
    }
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let modelIndexPath = viewIndexPathToModelIndexPath(indexPath)
    let item = sections[modelIndexPath.section].items[modelIndexPath.item]
    if let rowHeight = item.rowHeight {
      return rowHeight
    }
    return tableView.rowHeight
  }

  func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    let section = sections[viewSectionToModelSection(section)]
    if (section.headerTitle ?? "").isEmpty {
      return 12
    }
    if useSectionHeaderHeightFromView {
      return tableView.sectionHeaderHeight
    }
    return UITableView.automaticDimension
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
    s.footerTitle = footer

    let index = sections.count
    sections.append(s)

    if isInitialised {
      tableView.insertSections([index], with: kHideShowAnimation)
    }

    return IndexPath(index: index)
  }

  @discardableResult func addSection() -> IndexPath {
    add(section: nil, footer: nil)
  }

  @discardableResult func add(_ item: any TableModelItem, toSection sectionIndex: Int,
                              hidden: Bool = false) -> IndexPath {
    sections[sectionIndex].items.append(item)

    let path = IndexPath(row: sections[sectionIndex].items.count - 1, section: sectionIndex)
    if hidden {
      sections[sectionIndex].hiddenItems.add(path.row)
    } else if isInitialised {
      tableView.insertRows(at: [modelIndexPathToViewIndexPath(path)], with: kHideShowAnimation)
    }
    return path
  }

  @discardableResult func add(_ item: any TableModelItem, hidden: Bool = false) -> IndexPath {
    if sections.isEmpty {
      _ = addSection()
    }
    return add(item, toSection: sections.count - 1, hidden: hidden)
  }

  @discardableResult func insert(_ item: any TableModelItem, atIndex index: Int,
                                 inSection section: Int) -> IndexPath {
    sections[section].items.insert(item, at: index)
    let path = IndexPath(row: index, section: section)

    if isInitialised {
      tableView.insertRows(at: [modelIndexPathToViewIndexPath(path)], with: kHideShowAnimation)
    }

    return path
  }

  func sort<T>(section: Int, using fn: (T, T) -> Bool) {
    sections[section].items.sort(by: { a, b -> Bool in
      fn(a as! T, b as! T)
    })

    if isInitialised {
      tableView.reloadSections([section], with: kHideShowAnimation)
    }
  }

  func reloadTable() {
    tableView.reloadData()
  }
}
