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

import FMDB
import Foundation
import SwiftProtobuf

extension FMDatabaseQueue {
  /** Convenience inTransaction wrapper that lets the block return a value. */
  func inTransaction<T>(fn: (FMDatabase) -> (T)) -> T {
    var ret: T!
    inTransaction { db, _ in
      ret = fn(db)
      db.closeOpenResultSets()
    }
    return ret
  }

  /** Convenience inDatabase wrapper that lets the block return a value. */
  func inDatabase<T>(fn: (FMDatabase) -> (T)) -> T {
    var ret: T!
    inDatabase { db in
      ret = fn(db)
      db.closeOpenResultSets()
    }
    return ret
  }
}

extension FMDatabase {
  /** Executes the SQL statements, crashing the process if they fail. */
  func mustExecuteStatements(_ sql: String) {
    if !executeStatements(sql) {
      fatalError("DB query failed: \(lastErrorMessage())\nQuery: \(sql)")
    }
  }

  /** Executes the SQL update, crashing the process if it fails. */
  func mustExecuteUpdate(_ sql: String, args: [Any] = []) {
    if !executeUpdate(sql, withArgumentsIn: args) {
      fatalError("DB query failed: \(lastErrorMessage())\nQuery: \(sql)")
    }
  }

  /** Executes the SQL query, crashing the process if it fails. */
  func query(_ sql: String, args: [Any] = []) -> FMResultSet {
    if let result = executeQuery(sql, withArgumentsIn: args) {
      return result
    }
    fatalError("DB query failed: \(lastErrorMessage())\nQuery: \(sql)")
  }
}

/** Extends FMResultSet to implement the Sequence protocol. */
extension FMResultSet: Sequence {
  public struct Iterator: IteratorProtocol {
    public typealias Element = FMResultSet

    public mutating func next() -> FMResultSet? {
      if resultSet.next() {
        return resultSet
      }
      return nil
    }

    var resultSet: FMResultSet
  }

  public __consuming func makeIterator() -> FMResultSet.Iterator {
    Iterator(resultSet: self)
  }
}

/** Protobuf decoding methods. */
extension FMResultSet {
  public func proto<T: SwiftProtobuf.Message>(forColumnIndex columnIndex: Int) -> T? {
    guard let d = data(forColumnIndex: Int32(columnIndex)) else {
      return nil
    }
    return try? T(serializedData: d)
  }

  public func proto<T: SwiftProtobuf.Message>(forColumn column: String) -> T? {
    guard let d = data(forColumn: column) else {
      return nil
    }
    return try? T(serializedData: d)
  }
}
