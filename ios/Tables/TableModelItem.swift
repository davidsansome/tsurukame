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

import Foundation

enum TableModelCellFactory {
  case fromInterfaceBuilder(nibName: String)
  case fromFunction(function: () -> TableModelCell)
  case fromDefaultConstructor(cellClass: UITableViewCell.Type)
}

protocol TableModelItem: AnyObject {
  var cellFactory: TableModelCellFactory { get }

  var cellReuseIdentifier: String { get }
  var rowHeight: CGFloat? { get }
}

extension TableModelItem {
  var cellReuseIdentifier: String { String(describing: self.self) }
  var rowHeight: CGFloat? { nil }
}

class TableModelCell: UITableViewCell {
  unowned var baseItem: (any TableModelItem)!
  unowned var tableView: UITableView!

  func update() {}
  func didSelect() {}
}

@propertyWrapper
struct TypedModelItem<ItemType> {
  static subscript<CellType: TableModelCell>(_enclosingInstance instance: CellType,
                                             wrapped _: ReferenceWritableKeyPath<CellType,
                                               ItemType>,
                                             storage _: ReferenceWritableKeyPath<CellType, Self>)
    -> ItemType {
    get {
      instance.baseItem as! ItemType
    }
    set {
      fatalError()
    }
  }

  @available(*, unavailable,
             message: "This property wrapper can only be applied to classes")
  var wrappedValue: ItemType {
    get { fatalError() }
    set { fatalError() }
  }
}
