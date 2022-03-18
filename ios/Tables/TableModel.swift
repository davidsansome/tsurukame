// Copyright 2022 David Sansome
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

@objc(TKMTableModel)
@objcMembers
class TableModel: NSObject, UITableViewDataSource, UITableViewDelegate {
  struct Section {
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

  @objc(itemsInSection:)
  func items(inSection section: Int) -> [TKMModelItem] {
    sections[section].items
  }

  // MARK: - Hiding items

  func setIndexPath(_ index: IndexPath, hidden: Bool) {
    if hidden == isIndexPathHidden(index) {
      return
    }

    let set = sections[index.section].hiddenItems
    if hidden {
      set.add(index.row)
    } else {
      set.remove(index.row)
    }

    if isInitialised {
      if hidden {
        tableView.deleteRows(at: [index], with: .automatic)
      } else {
        tableView.insertRows(at: [index], with: .automatic)
      }
    }
  }

  func isIndexPathHidden(_ index: IndexPath) -> Bool {
    sections[index.section].hiddenItems.contains(index.row)
  }

  // MARK: - UITableViewDataSource

  func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let section = sections[indexPath.section]
    var row = indexPath.row
    section.hiddenItems.enumerate { i, _ in
      if i <= row {
        row += 1
      }
    }
    return cell(item: section.items[row])
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
    sections[section].headerTitle
  }

  func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
    sections[section].headerFooter
  }

  func numberOfSections(in _: UITableView) -> Int {
    isInitialised = true
    return sections.count
  }

  func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    let s = sections[section]
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
    let item = sections[indexPath.section].items[indexPath.item]
    if item.responds(to: #selector(TKMModelItem.rowHeight)) {
      return item.rowHeight!()
    }
    return tableView.rowHeight
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

@objc(TKMMutableTableModel)
@objcMembers
class MutableTableModel: TableModel {
  @objc(addSection:footer:)
  @discardableResult func add(section: String?, footer: String? = nil) -> Int {
    var s = Section()
    s.headerTitle = section
    s.headerFooter = footer

    let index = sections.count
    sections.append(s)
    return index
  }

  // For objective-c only.
  @objc(addSection:)
  @discardableResult func _add(section: String?) -> Int {
    add(section: section)
  }

  @discardableResult func addSection() -> Int {
    add(section: nil, footer: nil)
  }

  @objc(addItem:to:isHidden:)
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

  // For objective-c only.
  @objc(addItem:)
  @discardableResult func _add(item: TKMModelItem) -> IndexPath {
    add(item, hidden: false)
  }

  @discardableResult func insert(_ item: TKMModelItem, atIndex index: Int,
                                 inSection section: Int) -> IndexPath {
    sections[section].items.insert(item, at: index)
    return IndexPath(row: index, section: section)
  }

  func sort<T>(section: Int, using fn: (T, T) -> Bool) {
    sections[section].items.sort(by: { (a, b) -> Bool in
      fn(a as! T, b as! T)
    })
  }

  func reloadTable() {
    tableView.reloadData()
  }
}
