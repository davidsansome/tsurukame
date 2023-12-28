// Copyright 2023 David Sansome
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

// A view controller that shows a list of possible choices for a single Setting.
// The current value of the Setting is checked, and the default value is given a "(default)" suffix.
class SettingChoiceListViewController<T: SettingProtocol>: UITableViewController,
  TKMViewController
  where T.ValueType: Equatable {
  private var setting: T
  private var model: MutableTableModel!

  // An optional function that's called when the user taps a choice, after the setting is saved and
  // before the view controller is popped.
  var saveFn: ((_ newValue: T.ValueType) -> Void)?

  var canSwipeToGoBack: Bool { true }

  init(setting: T, title: String, helpText: String? = nil) {
    self.setting = setting

    if #available(iOS 13.0, *) {
      super.init(style: .insetGrouped)
    } else {
      super.init(style: .grouped)
    }

    self.title = title
    model = MutableTableModel(tableView: tableView)
    model.add(section: nil, footer: helpText)

    tableView.backgroundColor = TKMStyle.Color.background
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // Adds a choice for each possible enum value. The Setting must be an EnumSetting.
  func addChoicesFromEnum() where T.ValueType: SettingEnum {
    for c in T.ValueType.allCases {
      addChoice(name: String(describing: c), value: c)
    }
  }

  // Adds a choice for each item in the Sequence.
  func addChoicesFromRange<S>(_ range: S, suffix: String) where S: Sequence,
    S.Element == T.ValueType {
    for value in range {
      addChoice(name: "\(value)\(suffix)", value: value)
    }
  }

  func addChoices(_ choices: KeyValuePairs<String, T.ValueType>) {
    for choice in choices {
      addChoice(name: choice.key, value: choice.value)
    }
  }

  func addChoice(name: String, value: T.ValueType) {
    let isSelected = value == setting.wrappedValue
    let isDefault = value == setting.defaultValue
    let defaultText = isDefault ? " (default)" : ""

    model.add(BasicModelItem(style: .default, title: "\(name)\(defaultText)",
                             accessoryType: isSelected ? .checkmark : .none) {
        self.setting.wrappedValue = value
        self.saveFn?(value)
        self.navigationController?.popViewController(animated: true)
      })
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    model.reloadTable()
  }
}
