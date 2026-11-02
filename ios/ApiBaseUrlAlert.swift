// Copyright David Sansome
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
import UIKit
import WaniKaniAPI

enum ApiBaseUrlAlert {
  // Asks the user for a new API base URL, validates it and saves it to Settings.apiBaseUrl.
  // onChange is called with the new URL after it's saved.
  static func present(from vc: UIViewController, onChange: @escaping (String) -> Void) {
    let c = UIAlertController(title: "API base URL",
                              message: "Default: \(WaniKaniAPIClient.defaultBaseUrl)",
                              preferredStyle: .alert)
    c.addTextField { field in
      field.text = Settings.apiBaseUrl
      field.placeholder = WaniKaniAPIClient.defaultBaseUrl
      field.keyboardType = .URL
      field.autocapitalizationType = .none
      field.autocorrectionType = .no
      field.clearButtonMode = .whileEditing
    }
    c.addAction(UIAlertAction(title: "Save", style: .default) { [weak vc] _ in
      guard let vc = vc else { return }
      set(c.textFields?.first?.text ?? "", from: vc, onChange: onChange)
    })
    c.addAction(UIAlertAction(title: "Reset to default", style: .destructive) { [weak vc] _ in
      guard let vc = vc else { return }
      set(WaniKaniAPIClient.defaultBaseUrl, from: vc, onChange: onChange)
    })
    c.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    vc.present(c, animated: true, completion: nil)
  }

  private static func set(_ text: String, from vc: UIViewController,
                          onChange: (String) -> Void) {
    var url = text.trimmingCharacters(in: .whitespacesAndNewlines)
    while url.hasSuffix("/") {
      url.removeLast()
    }
    if url.isEmpty {
      url = WaniKaniAPIClient.defaultBaseUrl
    }

    guard let parsed = URL(string: url), let scheme = parsed.scheme?.lowercased(),
          scheme == "http" || scheme == "https", parsed.host != nil else {
      let c = UIAlertController(title: "Invalid URL",
                                message: "\"\(url)\" isn't a valid http or https URL.",
                                preferredStyle: .alert)
      c.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      vc.present(c, animated: true, completion: nil)
      return
    }

    Settings.apiBaseUrl = url
    onChange(url)
  }
}
