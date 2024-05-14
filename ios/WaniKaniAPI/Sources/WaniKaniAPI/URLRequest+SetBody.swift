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

extension CharacterSet {
  // By default URLComponents.percentEncodedQuery doesn't encode the '+' character. The WaniKani
  // server interprets this as a space instead, so make our own character set.
  static let rfc3986Unreserved =
    CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

public extension URLRequest {
  mutating func setJSONBody<T: Codable>(method: String, body: T) throws {
    let data = try JSONEncoder().encode(body)

    setValue("application/json", forHTTPHeaderField: "Content-Type")
    setValue(String(data.count), forHTTPHeaderField: "Content-Length")
    NSLog("JSON body: %@", String(data: data, encoding: .utf8)!)
    httpBody = data
    httpMethod = method
  }

  mutating func setFormBody(method: String, queryItems: [URLQueryItem]) throws {
    // Build the query string manually. We can't use URLComponents.percentEncodedQuery because it
    // doesn't let us use custom character sets, and we can't use String.addingPercentEncoding on
    // the whole thing because it would leave = and & unencoded.
    var encodedQueryItems = [String]()
    for queryItem in queryItems {
      let name = queryItem.name.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!
      let value = queryItem.value!.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!
      encodedQueryItems.append("\(name)=\(value)")
    }
    let query = encodedQueryItems.joined(separator: "&")
    let data = query.data(using: .utf8)!

    setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    setValue(String(data.count), forHTTPHeaderField: "Content-Length")
    httpBody = data
    httpMethod = method
  }
}
