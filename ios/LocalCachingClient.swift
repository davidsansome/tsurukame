// Copyright 2020 David Sansome
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
import Reachability

typealias SyncProgressHandler = (Double) -> Void
typealias CompletionHandler = () -> Void

private func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T {
  objc_sync_enter(lock)
  defer { objc_sync_exit(lock) }
  return try body()
}

extension FMDatabase {
  func stringForQuery(_ sql: String, _ values: Any...) -> String? {
    checkQuery(sql, values).string(forColumnIndex: 0)
  }

  func checkQuery(_ sql: String, _ values: Any...) -> FMResultSet {
    do { return try executeQuery(sql, values: values) }
    catch {
      fatalError("DB query failed:\n\(error)")
    }
  }

  func checkUpdate(_ sql: String, _ values: Any...) {
    do { try executeUpdate(sql, values: values) }
    catch { fatalError("DB query failed: \(lastErrorMessage())\nQuery: \(sql)") }
  }

  func checkExecuteStatements(_ sql: String) {
    if !executeStatements(sql) {
      fatalError("DB query failed: \(lastErrorMessage())\nQuery: \(sql)")
    }
  }
}

// Tracks one task that has a progress associated with it. Tasks are things like
// "fetch all assignments" or "upload all review progress". done/total here is how many network
// requests make up each one of those tasks. Often the total is not known until we do the first one,
// so these may be 0 to start with.
private struct ProgressTask {
  var done: Int32 = 0
  var total: Int32 = 0
}

private class SyncProgressTracker {
  let handler: SyncProgressHandler
  var tasks: [ProgressTask]
  var allocatedTasks: Int

  required init(handler: @escaping SyncProgressHandler, taskCount: Int) {
    self.handler = handler
    tasks = Array(repeating: ProgressTask(done: 0, total: 0), count: taskCount)
    allocatedTasks = 0
  }

  func update() {
    var done: Int32 = 0, total: Int32 = 0, progress: Double = 0
    for task in tasks {
      done += task.done
      total += max(1, task.total)
    }
    if total > 0 { progress = Double(done) / Double(total) }
    DispatchQueue.main.async { self.handler(progress) }
  }

  func newTask(group: DispatchGroup) -> PartialCompletionHandler {
    guard allocatedTasks < tasks.count else { fatalError("Too many tasks created") }
    let idx = allocatedTasks
    allocatedTasks += 1

    group.enter()
    return { (done: Int32, total: Int32) in
      self.tasks[idx] = ProgressTask(done: done, total: total)
      self.update()

      if done == total { group.leave() }
    }
  }
}

@objcMembers class LocalCachingClient: NSObject {
  // MARK: - Static Variables and Methods

  static let schemaV1 = """
  CREATE TABLE sync (
    assignments_updated_after TEXT,
    study_materials_updated_after TEXT
  );
  INSERT INTO sync (
    assignments_updated_after,
    study_materials_updated_after
  ) VALUES ("", "");
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
  """
  static let schemaV2 = """
  DELETE FROM assignments;
  UPDATE sync SET assignments_updated_after = "";
  ALTER TABLE assignments ADD COLUMN subject_id;
  CREATE INDEX idx_subject_id ON assignments (subject_id);
  """
  static let schemaV3 = """
  CREATE TABLE subject_progress (
    id INTEGER PRIMARY KEY,
    level INTEGER,
    srs_stage INTEGER,
    subject_type INTEGER
  );
  """
  static let schemaV4 = """
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
  """
  static let schemaV5 = """
  CREATE TABLE level_progressions (
    id INTEGER PRIMARY KEY,
    level INTEGER,
    pb BLOB
  );
  """
  static let clearAllData = """
  UPDATE sync SET
    assignments_updated_after = "",
    srs_systems_updated_after = "",
    study_materials_updated_after = ""
  ;
  DELETE FROM assignments;
  DELETE FROM pending_progress;
  DELETE FROM study_materials;
  DELETE FROM user;
  DELETE FROM pending_study_materials;
  DELETE FROM error_log;
  DELETE FROM level_progressions;
  DELETE FROM srs_systems;
  """
  static func addFakeAssignments(subjectIds: GPBInt32Array, subjectType: TKMSubject_Type,
                                 level: Int32, excludeSubjectIDs: Set<Int32>,
                                 assignments: inout [TKMAssignment]) {
    for i in 0 ..< subjectIds.count {
      let subjectID = subjectIds.value(at: i)
      if excludeSubjectIDs.contains(subjectID) { continue }
      let assignment = TKMAssignment()
      assignment.subjectId = subjectID
      assignment.subjectType = subjectType
      assignment.level = level
      assignments.append(assignment)
    }
  }

  static func datesAreSameHour(_ firstDate: Date?, _ secondDate: Date?) -> Bool {
    guard let a = firstDate, let b = secondDate else { return false }
    let calendar = Calendar.current
    let componentsA = calendar.dateComponents([.year, .month, .day, .hour], from: a)
    let componentsB = calendar.dateComponents([.year, .month, .day, .hour], from: b)
    return componentsA.hour! == componentsB.hour! && componentsA.day! == componentsB.day! &&
      componentsA.month! == componentsB.month! && componentsA.year! == componentsB.year!
  }

  static var databaseFilePath: String {
    "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/local-cache.db"
  }

  // MARK: - Initializer & Helpers

  var client: Client
  var dataLoader: DataLoader
  var reachability: Reachability

  var db: FMDatabaseQueue!
  var queue: DispatchQueue
  var busy = false

  var cachedAvailableLessonCount: Int32!
  var cachedAvailableReviewCount: Int32!
  var cachedUpcomingReviews: [Int32]!
  var cachedPendingProgress: Int32!
  var cachedPendingStudyMaterials: Int32!
  var cachedGuruKanjiCount: Int32!
  var cachedSRSLevelCounts: [Int32]!

  var isCachedAvailableSubjectCountsStale = true
  var isCachedPendingProgressStale = true
  var isCachedPendingStudyMaterialsStale = true
  var isCachedSRSLevelCountsStale = true
  var cachedAvailableSubjectCountsUpdated = Date.distantPast

  required init(client: Client, dataLoader: DataLoader, reachability: Reachability) {
    self.client = client
    self.dataLoader = dataLoader
    self.reachability = reachability
    queue = DispatchQueue.global(qos: .background)

    super.init()
    openDatabase()
  }

  func openDatabase() {
    let ret = FMDatabaseQueue(url: URL(fileURLWithPath: LocalCachingClient.databaseFilePath))!
    let schemas = [
      LocalCachingClient.schemaV1,
      LocalCachingClient.schemaV2,
      LocalCachingClient.schemaV3,
      LocalCachingClient.schemaV4,
      LocalCachingClient.schemaV5,
    ]
    var shouldPopulateSubjectProgress = false

    ret.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
      let targetVersion = schemas.count, currentVersion = Int(db.userVersion)
      if currentVersion >= targetVersion {
        NSLog("Database is up to date (version \(currentVersion))")
        return
      }
      for version in currentVersion ..< targetVersion {
        db.checkExecuteStatements(schemas[version])
        if version == 2 { shouldPopulateSubjectProgress = true }
        db.checkUpdate("PRAGMA user_version = \(targetVersion)")
        NSLog("Database updated to schema \(targetVersion)")
      }
    }
    db = ret

    if shouldPopulateSubjectProgress {
      db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
        let sql = """
        REPLACE INTO subject_progress (id, level, srs_stage, subject_type)
        VALUES (?, ?, ?, ?)
        """
        for assignment in self.getAllAssignments(in: db) {
          db.checkUpdate(sql, assignment.subjectId, assignment.level, assignment.srsStage,
                         assignment.subjectType)
        }
        for progress in self.getAllPendingProgress(in: db) {
          let assignment = progress.assignment!
          db.checkUpdate(sql, assignment.subjectId, assignment.level, assignment.srsStage,
                         assignment.subjectType)
        }
      }
    }

    // Remove any deleted subjects from the database.
    db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
      let deletedSubjectIDs = self.dataLoader.deletedSubjectIDs
      for i in 0 ..< deletedSubjectIDs.count {
        let subjectID = deletedSubjectIDs.value(at: i)
        db.checkUpdate("DELETE FROM assignments WHERE subject_id = ?", subjectID)
        db.checkUpdate("DELETE FROM subject_progress WHERE id = ?", subjectID)
      }
    }
  }

  // MARK: - Error handling

  func logError(_ error: Error) {
    let stack = Thread.callStackSymbols.description
    NSLog("Error \(error) at:\n\(stack)")

    // Don't bother logging these errors.
    if let urlErr = error as? URLError,
      urlErr.code == .timedOut || urlErr.code == .notConnectedToInternet { return }
    else if let posixErr = error as? POSIXError, posixErr.errorCode == ECONNABORTED { return }

    db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
      // Delete old log entries.
      db.checkUpdate("""
      DELETE FROM error_log WHERE ROWID IN (
        SELECT ROWID FROM error_log ORDER BY ROWID DESC LIMIT -1 OFFSET 99
      )
      """)
      guard let err = error as? TKMClientError else {
        let err = error as NSError
        db.checkUpdate("""
        INSERT INTO error_log (stack, code, description) VALUES (?, ?, ?)
        """, stack, err.code, err.description)
        return
      }
      db.checkUpdate("""
                     INSERT INTO error_log (stack, code, description, request_url, response_url,
                      request_data, request_headers, response_headers, response_data)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                     """, stack, err.code, err.localizedDescription,
                     err.request?.url?.description ?? "",
                     err.response?.url?.description ?? "",
                     (err.request?.httpBody != nil ? String(data: err.request!.httpBody!,
                                                            encoding: .utf8) : "") ?? "",
                     err.request?.allHTTPHeaderFields?.description ?? "",
                     err.response?.allHeaderFields.description ?? "",
                     (err
                       .responseData != nil ? String(data: err.responseData!, encoding: .utf8) :
                       "") ??
                       "")
    }
  }

  // MARK: - Local database getters

  func getAllAssignments() -> [TKMAssignment] {
    var ret: [TKMAssignment] = []
    db.inDatabase { ret = self.getAllAssignments(in: $0) }
    return ret
  }

  func getAllAssignments(in db: FMDatabase) -> [TKMAssignment] {
    var ret: [TKMAssignment] = [], r = db.checkQuery("SELECT pb FROM assignments")
    while r.next() {
      do { ret.append(try TKMAssignment(data: r.data(forColumnIndex: 0)!)) } catch {
        NSLog("Parsing TKMAssignment failed: \(error)")
        break
      }
    }
    return ret
  }

  func getAllPendingProgress() -> [TKMProgress] {
    var ret: [TKMProgress] = []
    db.inDatabase { ret = self.getAllPendingProgress(in: $0) }
    return ret
  }

  func getAllPendingProgress(in db: FMDatabase) -> [TKMProgress] {
    var ret: [TKMProgress] = [], r = db.checkQuery("SELECT pb FROM pending_progress")
    while r.next() { ret.append(try! TKMProgress(data: r.data(forColumnIndex: 0)!)) }
    return ret
  }

  func getStudyMaterial(id subjectID: Int32) -> TKMStudyMaterials? {
    var ret: TKMStudyMaterials?
    db.inDatabase {
      let r = $0.checkQuery("SELECT pb FROM study_materials WHERE id = ?", subjectID)
      while r.next() { ret = try? TKMStudyMaterials(data: r.data(forColumnIndex: 0)!) }
    }
    return ret
  }

  func getUserInfo() -> TKMUser? {
    var ret: TKMUser?
    db.inDatabase {
      let r = $0.checkQuery("SELECT pb FROM user")
      while r.next() { ret = try? TKMUser(data: r.data(forColumnIndex: 0)!) }
    }
    return ret
  }

  func countRows(in table: String) -> Int32 {
    var ret: Int32 = 0
    db.inDatabase {
      let r = $0.checkQuery("SELECT COUNT(*) FROM \(table)")
      while r.next() { ret = r.int(forColumnIndex: 0) }
    }
    return ret
  }

  func getAssignment(id subjectID: Int32) -> TKMAssignment? {
    var ret: TKMAssignment?
    db.inDatabase {
      var r = $0.checkQuery("SELECT pb FROM assignments WHERE subject_id = ?", subjectID)
      if r.next() {
        do { try ret = TKMAssignment(data: r.data(forColumnIndex: 0)!) }
        catch { NSLog("Parsing TKMAssignment failed: \(error)") }
        r.close()
        return
      }

      r = $0.checkQuery("SELECT pb FROM pending_progress WHERE id = ?", subjectID)
      if r.next() {
        do { ret = (try TKMProgress(data: r.data(forColumnIndex: 0)!)).assignment }
        catch { NSLog("Parsing TKMProgress failed: \(error)") }
        r.close()
      }
    }
    return ret
  }

  func getAssignments(level: Int32, transaction db: FMDatabase) -> [TKMAssignment] {
    guard level > 0 else { return [] }
    var ret: [TKMAssignment] = [], r = db.checkQuery("""
    SELECT p.id, p.level, p.srs_stage, p.subject_type, a.pb
     FROM subject_progress AS p
     LEFT JOIN assignments AS a
     ON p.id = a.subject_id
     WHERE p.level = ?
    """, level), subjectIDs: Set<Int32> = []
    while r.next() {
      let data = r.data(forColumnIndex: 4)
      var assignment: TKMAssignment
      if let _data = data { assignment = try! TKMAssignment(data: _data) } else {
        assignment = TKMAssignment()
        assignment.subjectId = r.int(forColumnIndex: 0)
        assignment.level = r.int(forColumnIndex: 1)
        assignment.subjectType = r.object(forColumnIndex: 3) as! TKMSubject_Type
      }
      assignment.srsStage = r.int(forColumnIndex: 2)
      ret.append(assignment)
      subjectIDs.insert(assignment.subjectId)
    }
    // Add fake assignments for any subjects that don't have assignments yet.
    let subjects = dataLoader.subjects(byLevel: Int(level))!
    LocalCachingClient.addFakeAssignments(subjectIds: subjects.radicalsArray, subjectType: .radical,
                                          level: level, excludeSubjectIDs: subjectIDs,
                                          assignments: &ret)
    LocalCachingClient.addFakeAssignments(subjectIds: subjects.kanjiArray, subjectType: .kanji,
                                          level: level, excludeSubjectIDs: subjectIDs,
                                          assignments: &ret)
    LocalCachingClient.addFakeAssignments(subjectIds: subjects.vocabularyArray,
                                          subjectType: .vocabulary, level: level,
                                          excludeSubjectIDs: subjectIDs, assignments: &ret)
    return ret
  }

  func getAssignments(level: Int32) -> [TKMAssignment] {
    if level > dataLoader.maxLevelGrantedBySubscription { return [] }
    var ret: [TKMAssignment] = []
    db.inDatabase { ret = self.getAssignments(level: level, transaction: $0) }
    return ret
  }

  func currentLevelAssignments() -> [TKMAssignment] {
    getAssignments(level: getUserInfo()?.currentLevel() ?? 1)
  }

  func currentKanji() -> Int32 {
    var count: Int32 = 0
    for assignment in currentLevelAssignments() {
      let subject = dataLoader.load(subjectID: Int(assignment.subjectId))!
      if subject.hasKanji { count += 1 }
    }
    return count
  }

  func currentPassedKanji() -> Int32 {
    var count: Int32 = 0
    for assignment in currentLevelAssignments() {
      let subject = dataLoader.load(subjectID: Int(assignment.subjectId))!
      if subject.hasKanji, assignment.hasPassedAt { count += 1 }
    }
    return count
  }

  func getTimeSpentPerLevel() -> [TimeInterval] {
    var ret: [TimeInterval] = []
    db.inDatabase {
      let r = $0.checkQuery("SELECT pb FROM level_progressions")
      while r.next() {
        do { ret.append(try TKMLevel(data: r.data(forColumnIndex: 0)!).timeSpentCurrent()) }
        catch { NSLog("Parsing TKMLevel failed: \(error)") }
      }
    }
    return ret
  }

  func getAverageRemainingLevelTime() -> TimeInterval {
    let timeSpentPerLevel = getTimeSpentPerLevel()
    if timeSpentPerLevel.count == 0 { return 0 }

    let currentLevelTime = timeSpentPerLevel.last!
    let lastPassIndex = timeSpentPerLevel.count - 1

    // Use median 50% to calculate average time
    let lowerIndex = lastPassIndex / 4 + (lastPassIndex % 4 == 3 ? 1 : 0)
    let upperIndex = lastPassIndex * 3 / 4 + (lastPassIndex == 1 ? 1 : 0)
    let medianPassTimes = timeSpentPerLevel[lowerIndex ..< upperIndex]
    let averageTime = medianPassTimes.reduce(0, +) / Double(medianPassTimes.count)
    return averageTime - currentLevelTime
  }

  // MARK: - Getting cached data

  var pendingProgress: Int32 {
    synchronized(self) {
      if isCachedPendingProgressStale {
        cachedPendingProgress = self.countRows(in: "pending_progress")
        isCachedPendingProgressStale = false
      }
      return cachedPendingProgress
    }
  }

  var pendingStudyMaterials: Int32 {
    synchronized(self) {
      if isCachedPendingStudyMaterialsStale {
        cachedPendingStudyMaterials = self.countRows(in: "pending_study_materials")
        isCachedPendingStudyMaterialsStale = false
      }
      return cachedPendingStudyMaterials
    }
  }

  var availableReviewCount: Int32 {
    synchronized(self) {
      updateAvailableSubjectCountsIfStale()
      return cachedAvailableReviewCount
    }
  }

  var availableLessonCount: Int32 {
    synchronized(self) {
      updateAvailableSubjectCountsIfStale()
      return cachedAvailableLessonCount
    }
  }

  var upcomingReviews: [Int32] {
    synchronized(self) {
      updateAvailableSubjectCountsIfStale()
      return cachedUpcomingReviews
    }
  }

  func updateAvailableSubjectCountsIfStale() {
    let now = Date()
    if !isCachedAvailableSubjectCountsStale,
      !LocalCachingClient.datesAreSameHour(now, cachedAvailableSubjectCountsUpdated) {
      invalidateCachedAvailableSubjectCounts()
    }
    if !isCachedAvailableSubjectCountsStale { return }

    var assignments = getAllAssignments(), lessons: Int32 = 0, reviews: Int32 = 0,
      upcomingReviews: [Int32] = Array(repeating: 0, count: 24 * 7)
    let userInfo = getUserInfo()

    for assignment in assignments {
      // Don't count assignments with invalid subjects.
      if !dataLoader.isValid(subjectID: Int(assignment.subjectId)) { continue }
      // Skip assignments moved above current level.
      if userInfo?.hasLevel ?? false {
        if userInfo!.level < assignment.level { continue }
      }

      if assignment.isLessonStage { lessons += 1 }
      else if assignment.isReviewStage {
        let availableInSeconds = assignment.availableAtDate.timeIntervalSince(now)
        guard availableInSeconds > 0 else {
          reviews += 1
          continue
        }
        let availableInHours = Int(availableInSeconds) / 3600
        if availableInHours < upcomingReviews.count {
          upcomingReviews[availableInHours] += 1
        }
      }
    }
    cachedAvailableLessonCount = lessons
    cachedAvailableReviewCount = reviews
    cachedUpcomingReviews = upcomingReviews
    isCachedAvailableSubjectCountsStale = false
    cachedAvailableSubjectCountsUpdated = now
  }

  func getSRSLevelCount(at level: TKMSRSStageCategory) -> Int32 {
    synchronized(self) {
      updateAvailableSRSCountsIfStale()
      return cachedSRSLevelCounts[Int(level.rawValue)]
    }
  }

  func getGuruKanjiCount() -> Int32 {
    synchronized(self) {
      updateAvailableSRSCountsIfStale()
      return cachedGuruKanjiCount
    }
  }

  func updateAvailableSRSCountsIfStale() {
    if !isCachedSRSLevelCountsStale { return }
    cachedSRSLevelCounts = Array(repeating: 0, count: 5)
    db.inDatabase {
      let guruResults = $0.checkQuery("""
      SELECT COUNT(*) FROM subject_progress WHERE srs_stage >= 5 AND subject_type = ?
      """, TKMSubject_Type.kanji)
      while guruResults.next() {
        cachedGuruKanjiCount = guruResults.int(forColumnIndex: 0)
      }

      let r = $0.checkQuery("""
      SELECT srs_stage, COUNT(*) FROM subject_progress WHERE srs_stage >= 1 GROUP BY srs_stage
      """)
      while r.next() {
        let srsStage = r.int(forColumnIndex: 0),
          count = r.int(forColumnIndex: 1),
          stageCategory = TKMSRSStageCategoryForStage(srsStage)
        cachedSRSLevelCounts[Int(stageCategory.rawValue)] += count
      }
    }
    isCachedSRSLevelCountsStale = false
  }

  // MARK: - Invalidating cached data

  func postNotificationOnMainThread(name string: String) {
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: NSNotification.Name(string), object: self)
    }
  }

  func invalidateCachedAvailableSubjectCounts() {
    synchronized(self) { isCachedAvailableSubjectCountsStale = true }
    postNotificationOnMainThread(name: "LocalCachingClientAvailableItemsChangedNotification")
  }

  func invalidateCachedPendingProgress() {
    synchronized(self) { isCachedPendingProgressStale = true }
    postNotificationOnMainThread(name: "LocalCachingClientPendingItemsChangedNotification")
  }

  func invalidatedCachedPendingStudyMaterials() {
    synchronized(self) { isCachedPendingStudyMaterialsStale = true }
    postNotificationOnMainThread(name: "LocalCachingClientPendingItemsChangedNotification")
  }

  func invalidateCachedSRSLevelCounts() {
    synchronized(self) { isCachedSRSLevelCountsStale = true }
    postNotificationOnMainThread(name: "LocalCachingClientSRSLevelCountsChangedNotification")
  }

  // MARK: - Send progress

  func sendProgress(_ progressArray: [TKMProgress]) {
    db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
      for progress in progressArray {
        // Delete the assignment.
        db.checkUpdate("DELETE FROM assignments WHERE id = ?", progress.assignment.id_p)
        // Store the progress locally.
        db.checkUpdate("REPLACE INTO pending_progress (id, pb) VALUES (?, ?)",
                       progress.assignment.subjectId, progress.data()!)

        var newSRSStage = progress.assignment.srsStage
        if progress
          .isLesson || (!progress.meaningWrong && !progress.readingWrong) { newSRSStage += 1 }
        else if progress.meaningWrong || progress
          .readingWrong { newSRSStage = max(0, newSRSStage - 1) }
        db.checkUpdate("""
                       REPLACE INTO subject_progress (id, level, srs_stage, subject_type) VALUES (?, ?, ?, ?)
                       """, progress.assignment.subjectId, progress.assignment.level, newSRSStage,
                       progress.assignment.subjectType)
      }
    }
    invalidateCachedPendingProgress()
    invalidateCachedAvailableSubjectCounts()
    invalidateCachedSRSLevelCounts()
    sendPendingProgress(progressArray, handler: nil)
  }

  func sendAllPendingProgress(handler: PartialCompletionHandler?) {
    sendPendingProgress(getAllPendingProgress(), handler: handler)
  }

  func sendPendingProgress(_ progressArray: [TKMProgress],
                           handler: PartialCompletionHandler?) {
    let total = Int32(progressArray.count)
    guard total > 0 else {
      if let completionHandler = handler { completionHandler(1, 1) }
      return
    }

    var complete: Int32 = 0
    for progress in progressArray {
      client.send(progress) { err in
        if let error = err {
          self.logError(error)
          if let clientErr = error as? TKMClientError {
            if clientErr.code == 401 {
              self.postNotificationOnMainThread(name: "LocalCachingClientUnauthorizedNotification")
            }
            // Drop the data if the server is telling us our data is invalid
            if clientErr.code == 422 {
              self.clearPendingProgress(progress)
            }
          }
        } else { self.clearPendingProgress(progress) }
        complete += 1
        if let completionHandler = handler { completionHandler(complete, total) }
      }
    }
  }

  func clearPendingProgress(_ progress: TKMProgress) {
    // Delete local pending progress.
    db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
      db.checkUpdate("DELETE FROM pending_progress WHERE id = ?", progress.assignment.subjectId)
    }
    invalidateCachedPendingProgress()
  }

  // MARK: - Send study materials

  func updateStudyMaterial(_ material: TKMStudyMaterials) {
    db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
      db.checkUpdate("""
      REPLACE INTO study_materials (id, pb) VALUES (?, ?)
      """, material.subjectId, material.data()!)
      db.checkUpdate("""
      REPLACE INTO pending_study_materials (id) VALUES(?)
      """, material.subjectId)
    }
    invalidatedCachedPendingStudyMaterials()
    sendPendingStudyMaterial(material, handler: nil)
  }

  func sendAllPendingStudyMaterials(handler: @escaping PartialCompletionHandler) {
    db.inDatabase {
      var total: Int32 = 0, complete: Int32 = 0
      let results = $0.checkQuery("""
      SELECT s.pb FROM study_materials AS s, pending_study_materials AS p ON s.id = p.id
      """)
      while results.next() {
        let material = try! TKMStudyMaterials(data: results.data(forColumnIndex: 0)!)
        NSLog("Sending pending study material update \(material.description)")
        total += 1
        sendPendingStudyMaterial(material) {
          complete += 1
          handler(complete, total)
        }
      }
      if total == 0 { handler(1, 1) }
    }
  }

  func sendPendingStudyMaterial(_ material: TKMStudyMaterials, handler: CompletionHandler?) {
    client.updateStudyMaterial(material) { err in
      if let error = err { self.logError(error) }
      else {
        self.db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
          db.checkUpdate("DELETE FROM pending_study_materials WHERE id = ?", material.subjectId)
        }
        self.invalidatedCachedPendingStudyMaterials()
      }
      if let completionHandler = handler { completionHandler() }
    }
  }

  // MARK: - Sync

  @objc(syncQuickly:handler:) func sync(quickly: Bool,
                                        progressHandler: @escaping SyncProgressHandler) {
    if !reachability.isReachable() {
      invalidateCachedAvailableSubjectCounts()
      progressHandler(1.0)
      return
    }
    queue.async {
      if self.busy { return }
      self.busy = true

      if !quickly {
        // Clear sync table, forcing redownload of all assignments.
        self.db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
          db.checkUpdate("UPDATE sync SET assignments_updated_after = \"\";")
        }
      }
      let tracker = SyncProgressTracker(handler: progressHandler, taskCount: 7)
      let sendGroup = DispatchGroup()
      self.sendAllPendingProgress(handler: tracker.newTask(group: sendGroup))
      self.sendAllPendingStudyMaterials(handler: tracker.newTask(group: sendGroup))

      sendGroup.notify(queue: self.queue) {
        let updateGroup = DispatchGroup()
        self.updateAssignments(handler: tracker.newTask(group: updateGroup))
        self.updateStudyMaterials(handler: tracker.newTask(group: updateGroup))
        self.updateUserInfo(handler: tracker.newTask(group: updateGroup))
        self.updateLevelProgression(handler: tracker.newTask(group: updateGroup))

        updateGroup.notify(queue: DispatchQueue.main) {
          self.busy = false
          self.invalidateCachedAvailableSubjectCounts()
          self.invalidateCachedSRSLevelCounts()
          self.postNotificationOnMainThread(name: "LocalCachingClientUserInfoChangedNotification")
        }
      }
    }
  }

  func updateAssignments(handler: @escaping PartialCompletionHandler) {
    // Get the last assignment update time.
    var lastDate: String?
    db.inDatabase {
      lastDate = $0.stringForQuery("SELECT assignments_updated_after FROM sync")
    }

    NSLog("Getting all assignments \(lastDate != nil ? "modified after \(lastDate!)" : "")")
    client.getAssignmentsModified(after: lastDate, progressHandler: handler) {
      if let error = $0 {
        self.logError(error)
        return
      }
      guard let dataUpdatedAt = $1 else { return }
      guard let assignments = $2 else { return }
      self.db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
        for assignment in assignments {
          db.checkUpdate("""
          REPLACE INTO assignments (id, pb, subject_id) VALUES (?, ?, ?)
          """, assignment.id_p, assignment.data()!, assignment.subjectId)
          db.checkUpdate("""
                         REPLACE INTO subject_progress (id, level, srs_stage, subject_type)
                          VALUES (?, ?, ?, ?)
                         """, assignment.subjectId, assignment.level, assignment.srsStage,
                         assignment.subjectType)
        }
        db.checkUpdate("UPDATE sync SET assignments_updated_after = ?", dataUpdatedAt)
      }
      NSLog("Recorded \(assignments.count) new assignments at \(dataUpdatedAt)")
      self.invalidateCachedAvailableSubjectCounts()
    }
  }

  func updateStudyMaterials(handler: @escaping PartialCompletionHandler) {
    // Get the last study materials update time.
    var lastDate: String?
    db.inDatabase {
      lastDate = $0.stringForQuery("SELECT study_materials_updated_after FROM sync")
    }

    NSLog("Getting all study materials \(lastDate != nil ? "modified after \(lastDate!)" : "")")
    client.getStudyMaterialsModified(after: lastDate, progressHandler: handler) {
      if let error = $0 {
        self.logError(error)
        return
      }
      guard let dataUpdatedAt = $1 else { return }
      guard let studyMaterials = $2 else { return }
      self.db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
        for material in studyMaterials {
          db.checkUpdate("REPLACE INTO study_materials (id, pb) VALUES (?, ?)", material.subjectId,
                         material.data()!)
        }
        db.checkUpdate("UPDATE sync SET study_materials_updated_after = ?", dataUpdatedAt)
      }
      NSLog("Recorded \(studyMaterials.count) new study materials at \(dataUpdatedAt)")
    }
  }

  func updateUserInfo(handler: @escaping PartialCompletionHandler) {
    client.getUserInfo {
      if let error = $0 {
        if let clientErr = error as? TKMClientError {
          if clientErr.code == 401 {
            self.postNotificationOnMainThread(name: "LocalCachingClientUnauthorizedNotification")
          }
        }
        self.logError(error)
      } else {
        guard let user = $1 else { return }
        self.db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
          db.checkUpdate("REPLACE INTO user (id, pb) VALUES (0, ?)", user.data()!)
        }
        NSLog("Got user info: \(user)")
      }
      handler(1, 1)
    }
  }

  func updateLevelProgression(handler: @escaping PartialCompletionHandler) {
    client.getLevelTimes {
      if let error = $0 {
        self.logError(error)
      } else {
        guard let levels = $1 else { return }
        self.db.inTransaction { (db: FMDatabase, _: UnsafeMutablePointer<ObjCBool>) in
          for level in levels {
            db.checkUpdate("REPLACE INTO level_progressions (id, level, pb) VALUES (?, ?, ?)",
                           level.id_p, level.level, level.data()!)
          }
          NSLog("Recorded \(levels.count) level progressions")
        }
      }
      handler(1, 1)
    }
  }

  func clearAllData() {
    db.inDatabase {
      $0.checkExecuteStatements(LocalCachingClient.clearAllData)
      NSLog("Database reset")
    }
  }

  func clearAllDataAndClose() {
    clearAllData()
    db.close()
  }
}
