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
import PromiseKit
import Reachability

extension Notification.Name {
  static let lccUnauthorized = Notification.Name(rawValue: "lccUnauthorized")
  static let lccAvailableItemsChanged = Notification.Name("lccAvailableItemsChanged")
  static let lccPendingItemsChanged = Notification.Name("lccPendingItemsChanged")
  static let lccUserInfoChanged = Notification.Name("lccUserInfoChanged")
  static let lccSRSCategoryCountsChanged = Notification.Name("lccSRSCategoryCountsChanged")
}

private func postNotificationOnMainQueue(_ notification: Notification.Name) {
  DispatchQueue.main.async {
    NotificationCenter.default.post(name: notification, object: nil)
  }
}

@objc class LocalCachingClient: NSObject, SubjectLevelGetter {
  let client: WaniKaniAPIClient
  let reachability: Reachability

  private var db: FMDatabaseQueue!

  @Cached(notificationName: .lccPendingItemsChanged) var pendingProgressCount: Int
  @Cached(notificationName: .lccPendingItemsChanged) var pendingStudyMaterialsCount: Int

  // swiftformat:disable all
  @Cached(notificationName: .lccAvailableItemsChanged) var availableSubjects: (
    lessonCount: Int,
    reviewCount: Int,
    upcomingReviews: [Int]
  )
  // swiftformat:enable all

  @Cached var guruKanjiCount: Int
  @Cached(notificationName: .lccSRSCategoryCountsChanged) var srsCategoryCounts: [Int]
  @objc @Cached var maxLevelGrantedBySubscription: Int

  init(client: WaniKaniAPIClient, reachability: Reachability) {
    self.client = client
    self.reachability = reachability

    super.init()
    openDatabase()

    _pendingProgressCount.updateBlock = {
      self.countRows(inTable: "pending_progress")
    }
    _pendingStudyMaterialsCount.updateBlock = {
      self.countRows(inTable: "pending_study_materials")
    }
    _availableSubjects.updateBlock = {
      self.updateAvailableSubjects()
    }
    _guruKanjiCount.updateBlock = {
      self.updateGuruKanjiCount()
    }
    _srsCategoryCounts.updateBlock = {
      self.updateSrsCategoryCounts()
    }
    _maxLevelGrantedBySubscription.updateBlock = {
      Int(self.getUserInfo()?.maxLevelGrantedBySubscription ?? 0)
    }
  }

  func updateGuruKanjiCount() -> Int {
    db.inDatabase { db in
      let cursor = db.query("SELECT COUNT(*) FROM subject_progress " +
        "WHERE srs_stage >= 5 AND subject_type = \(TKMSubject.TypeEnum.kanji.rawValue)")
      if cursor.next() {
        return Int(cursor.int(forColumnIndex: 0))
      }
      return 0
    }
  }

  func updateSrsCategoryCounts() -> [Int] {
    db.inDatabase { db in
      let cursor = db.query("SELECT srs_stage, COUNT(*) FROM subject_progress " +
        "WHERE srs_stage >= 1 GROUP BY srs_stage")

      var ret = Array(repeating: 0, count: 6)
      for cursor in cursor {
        let srsStage = cursor.int(forColumnIndex: 0)
        let count = Int(cursor.int(forColumnIndex: 1))
        let srsCategory = SRSStage(rawValue: Int(srsStage))!.category.rawValue
        ret[srsCategory] += count
      }
      return ret
    }
  }

  func updateAvailableSubjects() -> (Int, Int, [Int]) {
    guard let user = getUserInfo() else {
      return (0, 0, [])
    }

    let now = Date()
    var lessonCount = 0
    var reviewCount = 0
    var upcomingReviews = Array(repeating: 0, count: 48)

    for assignment in getAllAssignments() {
      // Don't count assignments with invalid subjects.  This includes assignments for levels higher
      // than the user's max subscription level.
      if !isValid(subjectId: assignment.subjectID) {
        continue
      }

      // Skip assignments that are a higher level than the user's current level. Wanikani items that
      // have moved to later levels can end up in this state and reviews will not be saved by the WK
      // API so they end up perpetually reviewed.
      if user.hasLevel, user.level < assignment.level {
        continue
      }

      if assignment.isLessonStage {
        lessonCount += 1
      } else if assignment.isReviewStage {
        let availableInSeconds = assignment.availableAtDate.timeIntervalSince(now)
        if availableInSeconds <= 0 {
          reviewCount += 1
          continue
        }
        let availableInHours = Int(availableInSeconds / (60 * 60))
        if availableInHours < upcomingReviews.count {
          upcomingReviews[availableInHours] += 1
        }
      }
    }

    return (lessonCount, reviewCount, upcomingReviews)
  }

  class func databaseUrl() -> URL {
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    return URL(fileURLWithPath: "\(paths[0])/local-cache.db")
  }

  private let schemas = [
    """
    CREATE TABLE sync (
      assignments_updated_after TEXT,
      study_materials_updated_after TEXT
    );
    INSERT INTO sync (
      assignments_updated_after,
      study_materials_updated_after
    ) VALUES (\"\", \"\");
    CREATE TABLE assignments (
      id INTEGER PRIMARY KEY,
      pb BLOB
    );
    CREATE TABLE pending_progress (
      id INTEGER PRIMARY KEY,
      pb BLOB
    );
    CREATE TABLE study_materials (
      id INTEGER PRIMARY KEY,
      pb BLOB
    );
    CREATE TABLE user (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      pb BLOB
    );
    CREATE TABLE pending_study_materials (
      id INTEGER PRIMARY KEY
    );
    """,

    """
    DELETE FROM assignments;
    UPDATE sync SET assignments_updated_after = \"\";
    ALTER TABLE assignments ADD COLUMN subject_id;
    CREATE INDEX idx_subject_id ON assignments (subject_id);
    """,

    """
    CREATE TABLE subject_progress (
      id INTEGER PRIMARY KEY,
      level INTEGER,
      srs_stage INTEGER,
      subject_type INTEGER
    );
    """,

    """
    CREATE TABLE error_log (
      date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      stack TEXT,
      code INTEGER,
      description TEXT,
      request_url TEXT,
      response_url TEXT,
      request_data TEXT,
      request_headers TEXT,
      response_headers TEXT,
      response_data TEXT
    );
    """,

    """
    CREATE TABLE level_progressions (
      id INTEGER PRIMARY KEY,
      level INTEGER,
      pb BLOB
    );
    """,

    """
    CREATE TABLE subjects (
      id INTEGER PRIMARY KEY,
      japanese TEXT,
      level INTEGER,
      type INTEGER,
      pb BLOB
    );
    CREATE INDEX idx_japanese ON subjects (japanese);
    CREATE INDEX idx_level ON subjects (level);
    ALTER TABLE sync ADD COLUMN subjects_updated_after TEXT;
    UPDATE sync SET subjects_updated_after = "";
    """,
  ]

  private let kClearAllData = """
  UPDATE sync SET
    assignments_updated_after = "",
    study_materials_updated_after = "",
    subjects_updated_after = ""
  ;
  DELETE FROM assignments;
  DELETE FROM pending_progress;
  DELETE FROM study_materials;
  DELETE FROM user;
  DELETE FROM pending_study_materials;
  DELETE FROM subject_progress;
  DELETE FROM error_log;
  DELETE FROM level_progressions;
  DELETE FROM subjects;
  """

  private func openDatabase() {
    db = FMDatabaseQueue(url: LocalCachingClient.databaseUrl())!
    db.inTransaction { db, _ in
      // Get the current version.
      let targetVersion = schemas.count
      let currentVersion = Int(db.userVersion)
      if currentVersion >= targetVersion {
        NSLog("Database up to date (version \(currentVersion))")
        return
      }

      // Update the table schema.
      var shouldPopulateSubjectProgress = false
      for version in currentVersion ..< targetVersion {
        db.mustExecuteStatements(schemas[version])

        if version == 2 {
          shouldPopulateSubjectProgress = true
        }
      }

      // Set the new schema version
      db.mustExecuteUpdate("PRAGMA user_version = \(targetVersion)")
      NSLog("Database updated to schema version \(targetVersion)")

      // Populate subject progress if we need to.
      if shouldPopulateSubjectProgress {
        let sql = "REPLACE INTO subject_progress (id, level, srs_stage, subject_type) " +
          "VALUES (?, ?, ?, ?)"
        for assignment in getAllAssignments(transaction: db) {
          db.mustExecuteUpdate(sql, args: [
            assignment.subjectID,
            assignment.level,
            assignment.srsStage.rawValue,
            assignment.subjectType.rawValue,
          ])
        }
        for progress in getAllPendingProgress(transaction: db) {
          let assignment = progress.assignment
          db.mustExecuteUpdate(sql, args: [
            assignment.subjectID,
            assignment.level,
            assignment.srsStage.rawValue,
            assignment.subjectType.rawValue,
          ])
        }
      }
    }
  }

  func getAllAssignments() -> [TKMAssignment] {
    db.inDatabase { db in
      getAllAssignments(transaction: db)
    }
  }

  private func getAllAssignments(transaction db: FMDatabase) -> [TKMAssignment] {
    var ret = [TKMAssignment]()
    for cursor in db.query("SELECT pb FROM assignments") {
      ret.append(cursor.proto(forColumnIndex: 0)!)
    }
    return ret
  }

  func getAllPendingProgress() -> [TKMProgress] {
    db.inDatabase { db in
      getAllPendingProgress(transaction: db)
    }
  }

  private func getAllPendingProgress(transaction db: FMDatabase) -> [TKMProgress] {
    var ret = [TKMProgress]()
    for cursor in db.query("SELECT pb FROM pending_progress") {
      ret.append(cursor.proto(forColumnIndex: 0)!)
    }
    return ret
  }

  func getStudyMaterial(subjectId: Int32) -> TKMStudyMaterials? {
    db.inDatabase { db in
      let cursor = db.query("SELECT pb FROM study_materials WHERE id = ?", args: [subjectId])
      if cursor.next() {
        return cursor.proto(forColumnIndex: 0)
      }
      return nil
    }
  }

  func getUserInfo() -> TKMUser? {
    db.inDatabase { db in
      let cursor = db.query("SELECT pb FROM user")
      if cursor.next() {
        return cursor.proto(forColumnIndex: 0)
      }
      return nil
    }
  }

  func countRows(inTable table: String) -> Int {
    db.inDatabase { db in
      let cursor = db.query("SELECT COUNT(*) FROM \(table)")
      if cursor.next() {
        return Int(cursor.int(forColumnIndex: 0))
      }
      return 0
    }
  }

  func getAssignment(subjectId: Int32) -> TKMAssignment? {
    db.inDatabase { db in
      var cursor = db.query("SELECT pb FROM assignments WHERE subject_id = ?", args: [subjectId])
      if cursor.next() {
        return cursor.proto(forColumnIndex: 0)
      }

      cursor = db.query("SELECT pb FROM pending_progress WHERE id = ?", args: [subjectId])
      if cursor.next() {
        let progress: TKMProgress = cursor.proto(forColumnIndex: 0)!
        return progress.assignment
      }

      return nil
    }
  }

  func getAssignments(level: Int) -> [TKMAssignment] {
    db.inDatabase { db in
      getAssignments(level: level, transaction: db)
    }
  }

  func getAssignmentsAtUsersCurrentLevel() -> [TKMAssignment] {
    guard let userInfo = getUserInfo() else {
      return []
    }
    return getAssignments(level: Int(userInfo.level))
  }

  private func getAssignments(level: Int, transaction db: FMDatabase) -> [TKMAssignment] {
    var ret = [TKMAssignment]()
    var subjectIds = Set<Int>()

    for cursor in db.query("SELECT p.id, p.level, p.srs_stage, p.subject_type, a.pb " +
      "FROM subject_progress AS p " +
      "LEFT JOIN assignments AS a " +
      "ON p.id = a.subject_id " +
      "WHERE p.level = ?", args: [level]) {
      var assignment: TKMAssignment? = cursor.proto(forColumnIndex: 4)
      if assignment == nil {
        assignment = TKMAssignment()
        assignment!.subjectID = cursor.int(forColumnIndex: 0)
        assignment!.level = cursor.int(forColumnIndex: 1)
        assignment!.subjectType = TKMSubject.TypeEnum(rawValue: Int(cursor.int(forColumnIndex: 3)))!
      }
      assignment!.srsStageNumber = cursor.int(forColumnIndex: 2)

      ret.append(assignment!)
      subjectIds.insert(Int(assignment!.subjectID))
    }

    // Add fake assignments for any other subjects at this level that don't have assignments yet (the
    // user hasn't unlocked the prerequisite radicals/kanji).
    let subjectsByLevel = getSubjects(byLevel: level, transaction: db)
    addFakeAssignments(to: &ret, subjectIds: subjectsByLevel.radicals, type: .radical,
                       level: level, excludeSubjectIds: subjectIds)
    addFakeAssignments(to: &ret, subjectIds: subjectsByLevel.kanji, type: .kanji, level: level,
                       excludeSubjectIds: subjectIds)
    addFakeAssignments(to: &ret, subjectIds: subjectsByLevel.vocabulary, type: .vocabulary,
                       level: level, excludeSubjectIds: subjectIds)

    return ret
  }

  private func addFakeAssignments(to assignments: inout [TKMAssignment],
                                  subjectIds: [Int32],
                                  type: TKMSubject.TypeEnum,
                                  level: Int,
                                  excludeSubjectIds: Set<Int>) {
    for id in subjectIds {
      if excludeSubjectIds.contains(Int(id)) {
        continue
      }
      var assignment = TKMAssignment()
      assignment.subjectID = id
      assignment.subjectType = type
      assignment.level = Int32(level)
      assignments.append(assignment)
    }
  }

  func getAllSubjects() -> [TKMSubject] {
    var ret = [TKMSubject]()
    db.inDatabase { db in
      for cursor in db.query("SELECT pb FROM subjects") {
        ret.append(cursor.proto(forColumnIndex: 0)!)
      }
    }
    return ret
  }

  func getSubject(id: Int32) -> TKMSubject? {
    db.inDatabase { db in
      let cursor = db.query("SELECT pb FROM subjects WHERE id = ?", args: [id])
      if cursor.next() {
        return cursor.proto(forColumnIndex: 0)
      }
      return nil
    }
  }

  func getSubject(japanese: String) -> TKMSubject? {
    db.inDatabase { db in
      let cursor = db.query("SELECT pb FROM subjects WHERE japanese = ?", args: [japanese])
      if cursor.next() {
        return cursor.proto(forColumnIndex: 0)
      }
      return nil
    }
  }

  func isValid(subjectId: Int32) -> Bool {
    guard let level = levelOf(subjectId: subjectId) else {
      return false
    }
    return level <= maxLevelGrantedBySubscription
  }

  func levelOf(subjectId: Int32) -> Int? {
    db.inDatabase { db in
      let cursor = db.query("SELECT level FROM subjects WHERE id = ?", args: [subjectId])
      if cursor.next() {
        return Int(cursor.int(forColumnIndex: 0))
      }
      return nil
    }
  }

  private func getSubjects(byLevel level: Int, transaction db: FMDatabase) -> TKMSubjectsByLevel {
    var ret = TKMSubjectsByLevel()
    let cursor = db.query("SELECT id, type FROM subjects WHERE level = ?", args: [level])
    while cursor.next() {
      let id = cursor.int(forColumnIndex: 0)
      let type = Int(cursor.int(forColumnIndex: 1))

      switch type {
      case TKMSubject.TypeEnum.radical.rawValue:
        ret.radicals.append(id)
      case TKMSubject.TypeEnum.kanji.rawValue:
        ret.kanji.append(id)
      case TKMSubject.TypeEnum.vocabulary.rawValue:
        ret.vocabulary.append(id)
      default:
        break
      }
    }
    return ret
  }

  func getAllLevelProgressions() -> [TKMLevel] {
    db.inDatabase { db in
      var ret = [TKMLevel]()
      for cursor in db.query("SELECT pb FROM level_progressions") {
        ret.append(cursor.proto(forColumnIndex: 0)!)
      }
      return ret
    }
  }

  func sendProgress(_ progress: [TKMProgress]) -> Promise<Void> {
    db.inTransaction { db in
      for p in progress {
        // Delete the assignment.
        db.mustExecuteUpdate("DELETE FROM assignments WHERE id = ?", args: [p.assignment.id])

        // Store the progress locally.
        db.mustExecuteUpdate("REPLACE INTO pending_progress (id, pb) VALUES (?, ?)",
                             args: [p.assignment.subjectID, try! p.serializedData()])

        var newSrsStage = p.assignment.srsStage
        if p.isLesson || (!p.meaningWrong && !p.readingWrong) {
          newSrsStage = newSrsStage.next
        } else if p.meaningWrong || p.readingWrong {
          newSrsStage = newSrsStage.previous
        }
        db.mustExecuteUpdate("REPLACE INTO subject_progress (id, level, srs_stage, subject_type) " +
          "VALUES (?, ?, ?, ?)",
          args: [
            p.assignment.subjectID,
            p.assignment.level,
            newSrsStage.rawValue,
            p.assignment.subjectType.rawValue,
          ])
      }
    }

    _pendingProgressCount.invalidate()
    _availableSubjects.invalidate()
    _srsCategoryCounts.invalidate()
    _guruKanjiCount.invalidate()

    return sendPendingProgress(progress, progress: Progress(totalUnitCount: -1))
  }

  private func sendAllPendingProgress(progress: Progress) -> Promise<Void> {
    sendPendingProgress(getAllPendingProgress(), progress: progress)
  }

  private func clearPendingProgress(_ progress: TKMProgress) {
    db.inTransaction { db in
      db.mustExecuteUpdate("DELETE FROM pending_progress WHERE id = ?",
                           args: [progress.assignment.subjectID])
    }
    _pendingProgressCount.invalidate()
  }

  private func sendPendingProgress(_ items: [TKMProgress], progress: Progress) -> Promise<Void> {
    if items.isEmpty {
      progress.totalUnitCount = 1
      progress.completedUnitCount = 1
      return .value(())
    }

    progress.totalUnitCount = Int64(items.count)

    // Send all progress, one at a time.
    var promise = Promise()
    for p in items {
      promise = promise.then { _ in
        self.client.sendProgress(p).asVoid()
      }.recover { err in
        if let apiError = err as? WaniKaniAPIError, apiError.code == 422 {
          // Drop the data if the server is clearly telling us our data is invalid and
          // cannot be accepted. This most commonly happens when doing reviews before
          // progress from elsewhere has synced, leaving the app trying to report
          // progress on reviews you already did elsewhere.
          return
        } else {
          throw err
        }
      }.map {
        self.clearPendingProgress(p)
      }.ensure {
        progress.completedUnitCount += 1
      }
    }
    return promise
  }

  func updateStudyMaterial(_ material: TKMStudyMaterials) -> Promise<Void> {
    db.inTransaction { db in
      // Store the study material locally.
      db.mustExecuteUpdate("REPLACE INTO study_materials (id, pb) VALUES(?, ?)",
                           args: [material.subjectID, try! material.serializedData()])
      db.mustExecuteUpdate("REPLACE INTO pending_study_materials (id) VALUES(?)",
                           args: [material.subjectID])
    }

    _pendingStudyMaterialsCount.invalidate()
    return sendPendingStudyMaterials([material], progress: Progress(totalUnitCount: 1))
  }

  private func getAllPendingStudyMaterials() -> [TKMStudyMaterials] {
    db.inDatabase { db in
      var ret = [TKMStudyMaterials]()
      for cursor in db
        .query("SELECT s.pb FROM study_materials AS s, pending_study_materials AS p ON s.id = p.id") {
        ret.append(cursor.proto(forColumnIndex: 0)!)
      }
      return ret
    }
  }

  private func sendAllPendingStudyMaterials(progress: Progress) -> Promise<Void> {
    sendPendingStudyMaterials(getAllPendingStudyMaterials(), progress: progress)
  }

  private func sendPendingStudyMaterials(_ materials: [TKMStudyMaterials],
                                         progress: Progress) -> Promise<Void> {
    if materials.isEmpty {
      progress.totalUnitCount = 1
      progress.completedUnitCount = 1
      return .value(())
    }

    progress.totalUnitCount = Int64(materials.count)

    // Send all study materials, one at a time.
    var promise = Promise.value(())
    for m in materials {
      promise = promise.then { _ in
        firstly {
          self.client.updateStudyMaterial(m).asVoid()
        }.map {
          self.clearPendingStudyMaterial(m)
        }.ensure {
          progress.completedUnitCount += 1
        }
      }
    }
    return promise
  }

  private func handleError(err: Error) {
    switch err {
    case let err as WaniKaniAPIError:
      switch err.code {
      case 401:
        postNotificationOnMainQueue(.lccUnauthorized)

      default:
        logError(code: err.code,
                 description: err.message,
                 request: err.request,
                 response: err.response,
                 responseData: nil)
      }
      return

    case let err as WaniKaniJSONDecodeError:
      logError(code: nil,
               description: err.error.localizedDescription,
               request: err.request,
               response: err.response,
               responseData: err.data)
      return

    case let err as URLError:
      if err.code == .notConnectedToInternet || err.code == .timedOut {
        return
      }

    case let err as POSIXError:
      if err.code == .ECONNABORTED {
        return
      }

    default:
      break
    }

    logError(code: nil,
             description: err.localizedDescription,
             request: nil,
             response: nil,
             responseData: nil)
  }

  private func logError(code: Int?, description: String?, request: URLRequest?,
                        response: HTTPURLResponse?, responseData: Data?) {
    let requestHeaders = request?.allHTTPHeaderFields?.description
    let responseHeaders = response?.allHeaderFields.description

    NSLog("Logging error: \(code ?? 0) \(description ?? "")")
    if let request = request {
      if let url = request.url {
        NSLog("Failed request URL: \(url)")
      }
      if let body = request.httpBody {
        NSLog("Failed request body: \(String(data: body, encoding: .utf8) ?? "")")
      }
    }
    if let response = response {
      NSLog("Failed response: \(response)")
    }
    if let responseData = responseData {
      NSLog("Failed response body: \(String(data: responseData, encoding: .utf8)!)")
    }

    db.inTransaction { db in
      // Delete old log entries.
      db.mustExecuteUpdate("""
          DELETE FROM error_log WHERE ROWID IN (
            SELECT ROWID FROM error_log ORDER BY ROWID DESC LIMIT -1 OFFSET 99
          )
      """)

      db.mustExecuteUpdate("""
          INSERT INTO error_log (
            code, description, request_url, response_url,
            request_data, request_headers, response_headers, response_data)
          VALUES (?,?,?,?,?,?,?,?)
      """, args: [code ?? NSNull(),
                  description ?? NSNull(),
                  request?.url?.absoluteString ?? NSNull(),
                  response?.url?.absoluteString ?? NSNull(),
                  request?.httpBody ?? NSNull(),
                  requestHeaders ?? NSNull(),
                  responseHeaders ?? NSNull(),
                  responseData ?? NSNull()])
    }
  }

  private func clearPendingStudyMaterial(_ material: TKMStudyMaterials) {
    db.inTransaction { db in
      db.mustExecuteUpdate("DELETE FROM pending_study_materials WHERE id = ?",
                           args: [material.subjectID])
    }
    _pendingStudyMaterialsCount.invalidate()
  }

  // MARK: - Syncing

  private func fetchAssignments(progress: Progress) -> Promise<Void> {
    // Get the last assignment update time.
    let updatedAfter: String = db.inDatabase { db in
      let cursor = db.query("SELECT assignments_updated_after FROM sync")
      if cursor.next() {
        return cursor.string(forColumnIndex: 0) ?? ""
      }
      return ""
    }

    return firstly { () -> Promise<WaniKaniAPIClient.Assignments> in
      client.assignments(progress: progress, updatedAfter: updatedAfter)
    }.done { assignments, updatedAt in
      NSLog("Updated %d assignments at %@", assignments.count, updatedAt)
      self.db.inTransaction { db in
        for assignment in assignments {
          db.mustExecuteUpdate("REPLACE INTO assignments (id, pb, subject_id) " +
            "VALUES (?, ?, ?)",
            args: [
              assignment.id,
              try! assignment.serializedData(),
              assignment.subjectID,
            ])
          db.mustExecuteUpdate("REPLACE INTO subject_progress (id, level, " +
            "srs_stage, subject_type) VALUES (?, ?, ?, ?)",
            args: [assignment.subjectID, assignment.level,
                   assignment.srsStage.rawValue,
                   assignment.subjectType.rawValue])
        }
        db.mustExecuteUpdate("UPDATE sync SET assignments_updated_after = ?",
                             args: [updatedAt])
      }
    }
  }

  private func fetchStudyMaterials(progress: Progress) -> Promise<Void> {
    // Get the last assignment update time.
    let updatedAfter: String = db.inDatabase { db in
      let cursor = db.query("SELECT study_materials_updated_after FROM sync")
      if cursor.next() {
        return cursor.string(forColumnIndex: 0) ?? ""
      }
      return ""
    }

    return firstly { () -> Promise<WaniKaniAPIClient.StudyMaterials> in
      client.studyMaterials(progress: progress, updatedAfter: updatedAfter)
    }.done { materials, updatedAt in
      NSLog("Updated %d study materials at %@", materials.count, updatedAt)
      self.db.inTransaction { db in
        for material in materials {
          db.mustExecuteUpdate("REPLACE INTO study_materials (id, pb) " +
            "VALUES (?, ?)",
            args: [material.subjectID, try! material.serializedData()])
        }
        db.mustExecuteUpdate("UPDATE sync SET study_materials_updated_after = ?",
                             args: [updatedAt])
      }
    }
  }

  // TODO: do everything on database queue.
  private func fetchUserInfo(progress: Progress) -> Promise<Void> {
    firstly {
      client.user(progress: progress)
    }.done { user in
      NSLog("Updated user: %@", user.debugDescription)
      let oldMaxLevel = self.maxLevelGrantedBySubscription
      self.db.inTransaction { db in
        db.mustExecuteUpdate("REPLACE INTO user (id, pb) VALUES (0, ?)",
                             args: [try! user.serializedData()])

        if oldMaxLevel > 0, user.maxLevelGrantedBySubscription > oldMaxLevel {
          // The user's max level increased, so more subjects might be available now. Clear the
          // sync marker to force all the subjects to be downloaded again next sync.
          db.mustExecuteUpdate("UPDATE sync SET subjects_updated_after = \"\"")
        }
      }
      if user.maxLevelGrantedBySubscription != oldMaxLevel {
        self._maxLevelGrantedBySubscription.invalidate()
      }
    }
  }

  private func fetchLevelProgression(progress: Progress) -> Promise<Void> {
    firstly {
      client.levelProgressions(progress: progress)
    }.done { progressions, _ in
      NSLog("Updated %d level progressions", progressions.count)
      self.db.inTransaction { db in
        for level in progressions {
          db.mustExecuteUpdate("REPLACE INTO level_progressions (id, level, pb) VALUES (?, ?, ?)",
                               args: [level.id, level.level, try! level.serializedData()])
        }
      }
    }
  }

  private func fetchSubjects(progress: Progress) -> Promise<Void> {
    // Get the last subject update time.
    let updatedAfter: String = db.inDatabase { db in
      let cursor = db.query("SELECT subjects_updated_after FROM sync")
      if cursor.next() {
        return cursor.string(forColumnIndex: 0) ?? ""
      }
      return ""
    }

    return firstly { () -> Promise<WaniKaniAPIClient.Subjects> in
      client.subjects(progress: progress, updatedAfter: updatedAfter)
    }.done { subjects, updatedAt in
      NSLog("Updated %d subjects at %@", subjects.count, updatedAt)
      self.db.inTransaction { db in
        for subject in subjects {
          db.mustExecuteUpdate("REPLACE INTO subjects (id, japanese, level, type, pb) " +
            "VALUES (?, ?, ?, ?, ?)",
            args: [
              subject.id,
              subject.japanese,
              subject.level,
              subject.subjectType.rawValue,
              try! subject.serializedData(),
            ])
        }
        db.mustExecuteUpdate("UPDATE sync SET subjects_updated_after = ?",
                             args: [updatedAt])
      }
    }
  }

  private var busy = false
  func sync(quick: Bool, progress: Progress) -> PMKFinalizer {
    guard !busy else {
      return Promise.value(()).cauterize()
    }
    busy = true

    let assignmentProgressUnits: Int64 = quick ? 1 : 8
    let subjectProgressUnits: Int64 = quick ? 1 : 20
    progress.totalUnitCount = 5 + assignmentProgressUnits + subjectProgressUnits
    let childProgress = { (units: Int64) in
      Progress(totalUnitCount: -1, parent: progress, pendingUnitCount: units)
    }

    if !quick {
      // Clear the sync table before doing anything else. This forces us to re-download all
      // assignments and subjects.
      db.inTransaction { db in
        db.mustExecuteStatements("""
        UPDATE sync
          SET assignments_updated_after = \"\",
              subjects_updated_after = \"\";
        """)
      }
    }

    return when(fulfilled: [
      sendAllPendingProgress(progress: childProgress(1)),
      sendAllPendingStudyMaterials(progress: childProgress(1)),

      // Fetch subjects before fetching anything else - we need to know subject levels to use them
      // in assignment protos.
      fetchSubjects(progress: childProgress(subjectProgressUnits)),
    ]).then { _ in
      when(fulfilled: [
        self.fetchAssignments(progress: childProgress(assignmentProgressUnits)),
        self.fetchStudyMaterials(progress: childProgress(1)),
        self.fetchUserInfo(progress: childProgress(1)),
        self.fetchLevelProgression(progress: childProgress(1)),
      ])
    }.done {
      self._availableSubjects.invalidate()
      self._srsCategoryCounts.invalidate()
      postNotificationOnMainQueue(.lccUserInfoChanged)
    }.ensure {
      self.busy = false
      progress.completedUnitCount = progress.totalUnitCount
    }.catch(handleError)
  }

  func clearAllData() {
    db.inDatabase { db in
      db.mustExecuteStatements(kClearAllData)
    }
    _maxLevelGrantedBySubscription.invalidate()
  }

  func clearAllDataAndClose() {
    clearAllData()
    db.close()
  }

  // MARK: - Objective-C support

  var availableReviewCount: Int {
    availableSubjects.reviewCount
  }

  var availableLessonCount: Int {
    availableSubjects.lessonCount
  }

  var upcomingReviews: [Int] {
    availableSubjects.upcomingReviews
  }
}

@propertyWrapper
struct Cached<T> {
  private var stale = true
  var value: T?
  var updateBlock: (() -> (T))?
  var notificationName: Notification.Name?

  init() {}

  init(notificationName: Notification.Name) {
    self.notificationName = notificationName
  }

  mutating func invalidate() {
    stale = true
    if let notificationName = notificationName {
      postNotificationOnMainQueue(notificationName)
    }
  }

  var wrappedValue: T {
    mutating get {
      if stale {
        value = updateBlock!()
        stale = false
      }
      return value!
    }
  }
}
