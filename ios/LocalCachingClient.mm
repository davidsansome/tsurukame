// Copyright 2018 David Sansome
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

#include <array>
#include <vector>

#import "Client.h"
#import "LocalCachingClient.h"
#import "Settings.h"

#import "proto/Wanikani+Convenience.h"

#import <sys/errno.h>

extern "C" {
#import <FMDB/FMDB.h>
#import "Tsurukame-Swift.h"
}

NS_ASSUME_NONNULL_BEGIN

typedef void (^CompletionHandler)();

NSNotificationName kLocalCachingClientAvailableItemsChangedNotification =
    @"kLocalCachingClientAvailableItemsChangedNotification";
NSNotificationName kLocalCachingClientPendingItemsChangedNotification =
    @"kLocalCachingClientPendingItemsChangedNotification";
NSNotificationName kLocalCachingClientUserInfoChangedNotification =
    @"kLocalCachingClientUserInfoChangedNotification";
NSNotificationName kLocalCachingClientUnauthorizedNotification =
    @"kLocalCachingClientUnauthorizedNotification";
NSNotificationName kLocalCachingClientSrsLevelCountsChangedNotification =
    @"kLocalCachingClientSrsLevelCountsChangedNotification";

static const char *kSchemaV1 =
    "CREATE TABLE sync ("
    "  assignments_updated_after TEXT,"
    "  study_materials_updated_after TEXT"
    ");"
    "INSERT INTO sync ("
    "  assignments_updated_after,"
    "  study_materials_updated_after"
    ") VALUES (\"\", \"\");"
    "CREATE TABLE assignments ("
    "  id INTEGER PRIMARY KEY,"
    "  pb BLOB"
    ");"
    "CREATE TABLE pending_progress ("
    "  id INTEGER PRIMARY KEY,"
    "  pb BLOB"
    ");"
    "CREATE TABLE study_materials ("
    "  id INTEGER PRIMARY KEY,"
    "  pb BLOB"
    ");"
    "CREATE TABLE user ("
    "  id INTEGER PRIMARY KEY CHECK (id = 0),"
    "  pb BLOB"
    ");"
    "CREATE TABLE pending_study_materials ("
    "  id INTEGER PRIMARY KEY"
    ");";

static const char *kSchemaV2 =
    "DELETE FROM assignments;"
    "UPDATE sync SET assignments_updated_after = \"\";"
    "ALTER TABLE assignments ADD COLUMN subject_id;"
    "CREATE INDEX idx_subject_id ON assignments (subject_id);";

static const char *kSchemaV3 =
    "CREATE TABLE subject_progress ("
    "  id INTEGER PRIMARY KEY,"
    "  level INTEGER,"
    "  srs_stage INTEGER,"
    "  subject_type INTEGER"
    ");";

static const char *kSchemaV4 =
    "CREATE TABLE error_log ("
    "  date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    "  stack TEXT,"
    "  code INTEGER,"
    "  description TEXT,"
    "  request_url TEXT,"
    "  response_url TEXT,"
    "  request_data TEXT,"
    "  request_headers TEXT,"
    "  response_headers TEXT,"
    "  response_data TEXT"
    ");";

static const char *kSchemaV5 =
    "CREATE TABLE level_progressions ("
    "  id INTEGER PRIMARY KEY,"
    "  level INTEGER,"
    "  pb BLOB"
    ");";

static const char *kClearAllData =
    "UPDATE sync SET"
    "  assignments_updated_after = \"\","
    "  study_materials_updated_after = \"\""
    ";"
    "DELETE FROM assignments;"
    "DELETE FROM pending_progress;"
    "DELETE FROM study_materials;"
    "DELETE FROM user;"
    "DELETE FROM pending_study_materials;"
    "DELETE FROM subject_progress;"
    "DELETE FROM error_log;"
    "DELETE FROM level_progressions;";

static void CheckUpdate(FMDatabase *db, NSString *sql, ...) {
  va_list args;
  va_start(args, sql);

  if (![db executeUpdate:sql withVAList:args]) {
    NSLog(@"DB query failed: %@\nQuery: %@", db.lastErrorMessage, sql);
    abort();
  }
  va_end(args);
}

static void CheckExecuteStatements(FMDatabase *db, NSString *sql) {
  if (![db executeStatements:sql]) {
    NSLog(@"DB query failed: %@\nQuery: %@", db.lastErrorMessage, sql);
    abort();
  }
}

static void AddFakeAssignments(GPBInt32Array *subjectIDs,
                               TKMSubject_Type subjectType,
                               int level,
                               NSSet<NSNumber *> *excludeSubjectIDs,
                               NSMutableArray<TKMAssignment *> *assignments) {
  for (int i = 0; i < subjectIDs.count; ++i) {
    int subjectID = [subjectIDs valueAtIndex:i];
    if ([excludeSubjectIDs containsObject:@(subjectID)]) {
      continue;
    }
    TKMAssignment *assignment = [TKMAssignment message];
    assignment.subjectId = subjectID;
    assignment.subjectType = subjectType;
    assignment.level = level;
    [assignments addObject:assignment];
  }
}

static BOOL DatesAreSameHour(NSDate *a, NSDate *b) {
  if (!a || !b) {
    return NO;
  }
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *componentsA = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                              fromDate:a];
  NSDateComponents *componentsB = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                              fromDate:b];
  return componentsA.hour == componentsB.hour && componentsA.day == componentsB.day &&
         componentsA.month == componentsB.month && componentsA.year == componentsB.year;
}

// Tracks one task that has a progress associated with it. Tasks are things like
// "fetch all assignments" or "upload all review progress". done/total here is how many network
// requests make up each one of those tasks. Often the total is not known until we do the first one,
// so these may be 0 to start with.
struct ProgressTask {
  int done = 0;
  int total = 0;
};

// Tracks the progress of multiple tasks that are involved in a sync.
@interface SyncProgressTracker : NSObject
@end

@implementation SyncProgressTracker {
  SyncProgressHandler _handler;
  std::vector<ProgressTask> _tasks;
  int _allocatedTasks;
}

- (instancetype)initWithProgressHandler:(SyncProgressHandler)handler taskCount:(int)taskCount {
  self = [super init];
  if (self) {
    _handler = handler;
    _tasks.resize(taskCount);
    _allocatedTasks = 0;
  }
  return self;
}

- (PartialCompletionHandler)newTaskInGroup:(dispatch_group_t)group {
  NSAssert(_allocatedTasks < _tasks.size(), @"Too many tasks created");
  __block NSUInteger idx = _allocatedTasks;
  _allocatedTasks++;

  dispatch_group_enter(group);

  return ^void(int done, int total) {
    _tasks[idx].done = done;
    _tasks[idx].total = total;
    [self update];

    if (done == total) {
      dispatch_group_leave(group);
    }
  };
}

- (void)update {
  int done = 0;
  int total = 0;
  for (const auto &task : _tasks) {
    done += task.done;
    total += task.total;
  }

  float progress = 0;
  if (total > 0) {
    progress = float(done) / total;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    _handler(progress);
  });
}

@end

@implementation LocalCachingClient {
  DataLoader *_dataLoader;
  Reachability *_reachability;
  FMDatabaseQueue *_db;
  dispatch_queue_t _queue;
  bool _busy;

  int _cachedAvailableLessonCount;
  int _cachedAvailableReviewCount;
  NSArray<NSNumber *> *_cachedUpcomingReviews;
  int _cachedPendingProgress;
  int _cachedPendingStudyMaterials;
  int _cachedGuruKanjiCount;
  std::array<int, 6> _cachedSrsLevelCounts;
  bool _isCachedAvailableSubjectCountsStale;
  bool _isCachedPendingProgressStale;
  bool _isCachedPendingStudyMaterialsStale;
  bool _isCachedSrsLevelCountsStale;
  NSDate *_cachedAvailableSubjectCountsUpdated;
}

#pragma mark - Initialisers

- (instancetype)initWithClient:(Client *)client
                    dataLoader:(DataLoader *)dataLoader
                  reachability:(Reachability *)reachability {
  self = [super init];
  if (self) {
    _client = client;
    _dataLoader = dataLoader;
    _reachability = reachability;
    [self openDatabase];
    assert(_db);
    _queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);

    _isCachedAvailableSubjectCountsStale = true;
    _isCachedPendingProgressStale = true;
    _isCachedPendingStudyMaterialsStale = true;
    _isCachedSrsLevelCountsStale = true;
    _cachedAvailableSubjectCountsUpdated = [NSDate distantPast];
  }
  return self;
}

+ (NSURL *)databaseFileUrl {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *fileName = [NSString stringWithFormat:@"%@/local-cache.db", paths[0]];

  return [NSURL fileURLWithPath:fileName];
}

- (void)openDatabase {
  FMDatabaseQueue *ret =
      [FMDatabaseQueue databaseQueueWithURL:[LocalCachingClient databaseFileUrl]];

  static NSArray<NSString *> *kSchemas;
  static dispatch_once_t once;
  dispatch_once(&once, ^(void) {
    kSchemas = @[
      @(kSchemaV1),
      @(kSchemaV2),
      @(kSchemaV3),
      @(kSchemaV4),
      @(kSchemaV5),
    ];
  });

  __block bool shouldPopulateSubjectProgress = false;

  [ret inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
    // Get the current version.
    NSUInteger targetVersion = kSchemas.count;
    NSUInteger currentVersion = db.userVersion;
    if (currentVersion >= targetVersion) {
      NSLog(@"Database up to date (version %lu)", (unsigned long)currentVersion);
      return;
    }
    for (; currentVersion < targetVersion; ++currentVersion) {
      CheckExecuteStatements(db, kSchemas[currentVersion]);

      if (currentVersion == 2) {
        shouldPopulateSubjectProgress = true;
      }
    }
    CheckUpdate(
        db, [NSString stringWithFormat:@"PRAGMA user_version = %lu", (unsigned long)targetVersion]);
    NSLog(@"Database updated to schema %lu", (unsigned long)targetVersion);
  }];

  _db = ret;

  if (shouldPopulateSubjectProgress) {
    [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
      NSString *sql =
          @"REPLACE INTO subject_progress (id, level, srs_stage, subject_type) "
           "VALUES (?, ?, ?, ?)";
      for (TKMAssignment *assignment in [self getAllAssignmentsInTransaction:db]) {
        CheckUpdate(db, sql, @(assignment.subjectId), @(assignment.level), @(assignment.srsStage),
                    @(assignment.subjectType));
      }
      for (TKMProgress *progress in [self getAllPendingProgressInTransaction:db]) {
        TKMAssignment *assignment = progress.assignment;
        CheckUpdate(db, sql, @(assignment.subjectId), @(assignment.level), @(assignment.srsStage),
                    @(assignment.subjectType));
      }
    }];
  }

  // Remove any deleted subjects from the database.
  [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
    GPBInt32Array *deletedSubjectIDs = _dataLoader.deletedSubjectIDs;
    for (int i = 0; i < deletedSubjectIDs.count; ++i) {
      int subjectID = [deletedSubjectIDs valueAtIndex:i];
      CheckUpdate(db, @"DELETE FROM assignments WHERE subject_id = ?", @(subjectID));
      CheckUpdate(db, @"DELETE FROM subject_progress WHERE id = ?", @(subjectID));
    }
  }];
}

#pragma mark - Error handling

- (void)logError:(NSError *)error {
  NSString *stack = [NSThread callStackSymbols].description;
  NSLog(@"Error %@ at:\n%@", error, stack);

  // Don't bother logging some common errors.
  if (([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorTimedOut) ||
      ([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet) ||
      ([error.domain isEqual:NSPOSIXErrorDomain] && error.code == ECONNABORTED)) {
    return;
  }

  [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
    // Delete old log entries.
    CheckUpdate(db,
                @"DELETE FROM error_log WHERE ROWID IN ("
                 "  SELECT ROWID FROM error_log ORDER BY ROWID DESC LIMIT -1 OFFSET 99"
                 ")");

    if (!TKMIsClientError(error)) {
      CheckUpdate(db,
                  @"INSERT INTO error_log (stack, code, description) "
                   "VALUES (?,?,?)",
                  stack, @(error.code), error.description);
      return;
    }

    TKMClientError *ce = (TKMClientError *)error;
    CheckUpdate(db,
                @"INSERT INTO error_log"
                 "(stack, code, description, request_url, response_url,"
                 " request_data, request_headers, response_headers, response_data) "
                 "VALUES (?,?,?,?,?,?,?,?,?)",
                stack, @(ce.code), ce.localizedDescription, ce.request.URL.description,
                ce.response.URL.description,
                [[NSString alloc] initWithData:ce.request.HTTPBody encoding:NSUTF8StringEncoding],
                ce.request.allHTTPHeaderFields.description, ce.response.allHeaderFields.description,
                [[NSString alloc] initWithData:ce.responseData encoding:NSUTF8StringEncoding]);
  }];
}

#pragma mark - Local database getters

- (NSArray<TKMAssignment *> *)getAllAssignments {
  __block NSArray<TKMAssignment *> *ret = nil;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    ret = [self getAllAssignmentsInTransaction:db];
  }];
  return ret;
}

- (NSArray<TKMAssignment *> *)getAllAssignmentsInTransaction:(FMDatabase *)db {
  NSMutableArray<TKMAssignment *> *ret = [NSMutableArray array];

  FMResultSet *r = [db executeQuery:@"SELECT pb FROM assignments"];
  while ([r next]) {
    NSError *error = nil;
    TKMAssignment *assignment = [TKMAssignment parseFromData:[r dataForColumnIndex:0] error:&error];
    if (error) {
      NSLog(@"Parsing TKMAssignment failed: %@", error);
      break;
    }
    [ret addObject:assignment];
  }

  return ret;
}

- (NSArray<TKMProgress *> *)getAllPendingProgress {
  __block NSArray<TKMProgress *> *progress = [NSMutableArray array];
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    progress = [self getAllPendingProgressInTransaction:db];
  }];
  return progress;
}

- (NSArray<TKMProgress *> *)getAllPendingProgressInTransaction:(FMDatabase *)db {
  NSMutableArray<TKMProgress *> *progress = [NSMutableArray array];
  FMResultSet *results = [db executeQuery:@"SELECT pb FROM pending_progress"];
  while ([results next]) {
    [progress addObject:[TKMProgress parseFromData:[results dataForColumnIndex:0] error:nil]];
  }
  return progress;
}

- (nullable TKMStudyMaterials *)getStudyMaterialForID:(int)subjectID {
  __block TKMStudyMaterials *ret = nil;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM study_materials WHERE id = ?", @(subjectID)];
    while ([r next]) {
      ret = [TKMStudyMaterials parseFromData:[r dataForColumnIndex:0] error:nil];
    }
  }];
  return ret;
}

- (nullable TKMUser *)getUserInfo {
  __block TKMUser *ret = nil;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM user"];
    while ([r next]) {
      ret = [TKMUser parseFromData:[r dataForColumnIndex:0] error:nil];
    }
  }];
  return ret;
}

- (int)countRowsInTable:(NSString *)tableName {
  __block int ret = 0;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", tableName];
    FMResultSet *r = [db executeQuery:sql];
    while ([r next]) {
      ret = [r intForColumnIndex:0];
    }
  }];
  return ret;
}

- (TKMAssignment *)getAssignmentForID:(int)subjectID {
  __block TKMAssignment *ret = nil;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    FMResultSet *r =
        [db executeQuery:@"SELECT pb FROM assignments WHERE subject_id = ?", @(subjectID)];
    if ([r next]) {
      NSError *error = nil;
      ret = [TKMAssignment parseFromData:[r dataForColumnIndex:0] error:&error];
      if (error) {
        NSLog(@"Parsing TKMAssignment failed: %@", error);
      }
      [r close];
      return;
    }

    r = [db executeQuery:@"SELECT pb FROM pending_progress WHERE id = ?", @(subjectID)];
    if ([r next]) {
      NSError *error = nil;
      TKMProgress *progress = [TKMProgress parseFromData:[r dataForColumnIndex:0] error:&error];
      if (error) {
        NSLog(@"Parsing TKMProgress failed: %@", error);
      }
      ret = progress.assignment;
      [r close];
    }
  }];
  return ret;
}

- (NSArray<TKMAssignment *> *)getAssignmentsAtLevel:(int)level inTransaction:(FMDatabase *)db {
  NSMutableArray<TKMAssignment *> *ret = [NSMutableArray array];
  FMResultSet *r = [db executeQuery:
                           @"SELECT p.id, p.level, p.srs_stage, p.subject_type, a.pb "
                            "FROM subject_progress AS p "
                            "LEFT JOIN assignments AS a "
                            "ON p.id = a.subject_id "
                            "WHERE p.level = ?",
                           @(level)];
  NSMutableSet<NSNumber *> *subjectIDs = [NSMutableSet set];
  while ([r next]) {
    NSData *data = [r dataForColumnIndex:4];
    TKMAssignment *assignment;
    if (data) {
      assignment = [TKMAssignment parseFromData:data error:nil];
    } else {
      assignment = [TKMAssignment message];
      assignment.subjectId = [r intForColumnIndex:0];
      assignment.level = [r intForColumnIndex:1];
      assignment.subjectType = static_cast<TKMSubject_Type>([r intForColumnIndex:3]);
    }
    assignment.srsStage = [r intForColumnIndex:2];
    [ret addObject:assignment];
    [subjectIDs addObject:@(assignment.subjectId)];
  }

  // Add fake assignments for any other subjects at this level that don't have assignments yet (the
  // user hasn't unlocked the prerequisite radicals/kanji).
  TKMSubjectsByLevel *subjectsByLevel = [_dataLoader subjectsByLevel:level];
  AddFakeAssignments(
      subjectsByLevel.radicalsArray, TKMSubject_Type_Radical, level, subjectIDs, ret);
  AddFakeAssignments(subjectsByLevel.kanjiArray, TKMSubject_Type_Kanji, level, subjectIDs, ret);
  AddFakeAssignments(
      subjectsByLevel.vocabularyArray, TKMSubject_Type_Vocabulary, level, subjectIDs, ret);

  return ret;
}

- (nullable NSArray<TKMAssignment *> *)getAssignmentsAtLevel:(int)level {
  if (level > _dataLoader.maxLevelGrantedBySubscription) {
    return nil;
  }

  __block NSArray<TKMAssignment *> *ret = nil;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    ret = [self getAssignmentsAtLevel:level inTransaction:db];
  }];
  return ret;
}

- (nullable NSArray<TKMAssignment *> *)getAssignmentsAtUsersCurrentLevel {
  TKMUser *user = [self getUserInfo];
  return [self getAssignmentsAtLevel:[user currentLevel]];
}

- (NSArray<NSNumber *> *)getTimeSpentAtEachLevel {
  __block NSMutableArray<NSNumber *> *ret = [NSMutableArray array];
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM level_progressions"];
    while ([r next]) {
      NSError *error = nil;
      TKMLevel *level = [TKMLevel parseFromData:[r dataForColumnIndex:0] error:&error];
      if (error) {
        NSLog(@"Parsing TKMLevel failed: %@", error);
      }
      [ret addObject:@([level timeSpentCurrent])];
    }
  }];
  return ret;
}

- (NSTimeInterval)getAverageRemainingLevelTime {
  NSArray<NSNumber *> *timeSpentAtEachLevel = [self getTimeSpentAtEachLevel];
  if ([timeSpentAtEachLevel count] == 0) {
    return 0;
  }

  NSNumber *currentLevelTime = [timeSpentAtEachLevel lastObject];
  NSUInteger lastPassIndex = [timeSpentAtEachLevel count] - 1;

  // Use the median 50% to calculate the average time
  NSUInteger lowerIndex = lastPassIndex / 4 + (lastPassIndex % 4 == 3 ? 1 : 0);
  NSUInteger upperIndex = lastPassIndex * 3 / 4 + (lastPassIndex == 1 ? 1 : 0);

  NSRange medianPassRange = NSMakeRange(lowerIndex, upperIndex - lowerIndex);
  NSArray *medianPassTimes = [timeSpentAtEachLevel subarrayWithRange:medianPassRange];
  NSNumber *averageTime = [medianPassTimes valueForKeyPath:@"@avg.self"];
  NSTimeInterval remainingTime = [averageTime doubleValue] - [currentLevelTime doubleValue];

  return remainingTime;
}

#pragma mark - Getting cached data

- (int)pendingProgress {
  @synchronized(self) {
    if (_isCachedPendingProgressStale) {
      _cachedPendingProgress = [self countRowsInTable:@"pending_progress"];
      _isCachedPendingProgressStale = false;
    }
    return _cachedPendingProgress;
  }
}

- (int)pendingStudyMaterials {
  @synchronized(self) {
    if (_isCachedPendingStudyMaterialsStale) {
      _cachedPendingStudyMaterials = [self countRowsInTable:@"pending_study_materials"];
      _isCachedPendingStudyMaterialsStale = false;
    }
    return _cachedPendingStudyMaterials;
  }
}

- (int)availableReviewCount {
#ifdef APP_STORE_SCREENSHOTS
  return 9;
#endif  // APP_STORE_SCREENSHOTS

  @synchronized(self) {
    [self maybeUpdateAvailableSubjectCounts];
    return _cachedAvailableReviewCount;
  }
}

- (int)availableLessonCount {
#ifdef APP_STORE_SCREENSHOTS
  return 10;
#endif  // APP_STORE_SCREENSHOTS

  @synchronized(self) {
    [self maybeUpdateAvailableSubjectCounts];
    return _cachedAvailableLessonCount;
  }
}

- (NSArray<NSNumber *> *)upcomingReviews {
#ifdef APP_STORE_SCREENSHOTS
  return @[
    @(14), @(8), @(2), @(1), @(12), @(42), @(17), @(9), @(2),  @(0), @(2), @(17),
    @(0),  @(0), @(6), @(0), @(0),  @(0),  @(0),  @(4), @(11), @(0), @(8), @(6)
  ];
#endif  // APP_STORE_SCREENSHOTS

  @synchronized(self) {
    [self maybeUpdateAvailableSubjectCounts];
    return _cachedUpcomingReviews;
  }
}

- (void)maybeUpdateAvailableSubjectCounts {
  NSDate *now = [NSDate date];
  if (!_isCachedAvailableSubjectCountsStale &&
      !DatesAreSameHour(now, _cachedAvailableSubjectCountsUpdated)) {
    [self invalidateCachedAvailableSubjectCounts];
  }
  if (!_isCachedAvailableSubjectCountsStale) {
    return;
  }

  NSArray<TKMAssignment *> *assignments = [self getAllAssignments];
  int lessons = 0;
  int reviews = 0;

  NSMutableArray<NSNumber *> *upcomingReviews = [NSMutableArray arrayWithCapacity:48];
  for (int i = 0; i < 24; i++) {
    [upcomingReviews addObject:@(0)];
  }

  for (TKMAssignment *assignment in assignments) {
    // Don't count assignments with invalid subjects.  This includes assignments for levels higher
    // than the user's max level.
    if (![_dataLoader isValidSubjectID:assignment.subjectId]) {
      continue;
    }

    if (assignment.isLessonStage) {
      lessons++;
    } else if (assignment.isReviewStage) {
      NSTimeInterval availableInSeconds = [assignment.availableAtDate timeIntervalSinceDate:now];
      if (availableInSeconds <= 0) {
        reviews++;
        continue;
      }
      int availableInHours = availableInSeconds / (60 * 60);
      if (availableInHours < upcomingReviews.count) {
        [upcomingReviews
                     setObject:[NSNumber
                                   numberWithInt:[upcomingReviews[availableInHours] intValue] + 1]
            atIndexedSubscript:availableInHours];
      }
    }
  }

  _cachedAvailableLessonCount = lessons;
  _cachedAvailableReviewCount = reviews;
  _cachedUpcomingReviews = upcomingReviews;
  _isCachedAvailableSubjectCountsStale = false;
  _cachedAvailableSubjectCountsUpdated = now;
}

- (int)getSrsLevelCount:(TKMSRSStageCategory)level {
  @synchronized(self) {
    [self maybeUpdateCachedSrsLevelCounts];
    return _cachedSrsLevelCounts[level];
  }
}

- (int)getGuruKanjiCount {
  @synchronized(self) {
    [self maybeUpdateCachedSrsLevelCounts];
    return _cachedGuruKanjiCount;
  }
}

- (void)maybeUpdateCachedSrsLevelCounts {
  if (!_isCachedSrsLevelCountsStale) {
    return;
  }

  _cachedSrsLevelCounts.fill(0);
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    FMResultSet *gr = [db executeQuery:
                              @"SELECT COUNT(*) FROM subject_progress WHERE srs_stage "
                              @">= 5 AND subject_type = ?",
                              @(TKMSubject_Type_Kanji)];
    while ([gr next]) {
      _cachedGuruKanjiCount = [gr intForColumnIndex:0];
    }

    FMResultSet *r = [db executeQuery:
                             @"SELECT srs_stage, COUNT(*) FROM subject_progress "
                             @"WHERE srs_stage >= 2 GROUP BY srs_stage"];
    while ([r next]) {
      int srs_stage = [r intForColumnIndex:0];
      int count = [r intForColumnIndex:1];
      TKMSRSStageCategory stageCategory = TKMSRSStageCategoryForStage(srs_stage);
      _cachedSrsLevelCounts[stageCategory] += count;
    }
  }];

  _isCachedSrsLevelCountsStale = false;
}

#pragma mark - Invalidating cached data

- (void)postNotificationOnMainThread:(NSNotificationName)name {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:name object:self];
  });
}

- (void)invalidateCachedAvailableSubjectCounts {
  @synchronized(self) {
    _isCachedAvailableSubjectCountsStale = true;
  }
  [self postNotificationOnMainThread:kLocalCachingClientAvailableItemsChangedNotification];
}

- (void)invalidateCachedPendingProgress {
  @synchronized(self) {
    _isCachedPendingProgressStale = true;
  }
  [self postNotificationOnMainThread:kLocalCachingClientPendingItemsChangedNotification];
}

- (void)invalidateCachedPendingStudyMaterials {
  @synchronized(self) {
    _isCachedPendingStudyMaterialsStale = true;
  }
  [self postNotificationOnMainThread:kLocalCachingClientPendingItemsChangedNotification];
}

- (void)invalidateCachedSrsLevelCounts {
  @synchronized(self) {
    _isCachedSrsLevelCountsStale = true;
  }
  [self postNotificationOnMainThread:kLocalCachingClientSrsLevelCountsChangedNotification];
}

#pragma mark - Send progress

- (void)sendProgress:(NSArray<TKMProgress *> *)progress {
  [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
    for (TKMProgress *p in progress) {
      // Delete the assignment.
      CheckUpdate(db, @"DELETE FROM assignments WHERE id = ?", @(p.assignment.id_p));

      // Store the progress locally.
      CheckUpdate(db, @"REPLACE INTO pending_progress (id, pb) VALUES (?, ?)",
                  @(p.assignment.subjectId), p.data);

      int newSrsStage = p.assignment.srsStage;
      if (p.isLesson || (!p.meaningWrong && !p.readingWrong)) {
        newSrsStage++;
      } else if (p.meaningWrong || p.readingWrong) {
        newSrsStage = MAX(0, newSrsStage - 1);
      }
      CheckUpdate(db,
                  @"REPLACE INTO subject_progress (id, level, srs_stage, subject_type) "
                   "VALUES (?, ?, ?, ?)",
                  @(p.assignment.subjectId), @(p.assignment.level), @(newSrsStage),
                  @(p.assignment.subjectType));
    }
  }];
  [self invalidateCachedPendingProgress];
  [self invalidateCachedAvailableSubjectCounts];
  [self invalidateCachedSrsLevelCounts];

  [self sendPendingProgress:progress handler:nil];
}

- (void)sendAllPendingProgress:(PartialCompletionHandler)handler {
  NSArray<TKMProgress *> *progress = [self getAllPendingProgress];
  [self sendPendingProgress:progress handler:handler];
}

- (void)sendPendingProgress:(NSArray<TKMProgress *> *)progress
                    handler:(PartialCompletionHandler _Nullable)handler {
  const int total = (int)progress.count;
  if (!total) {
    if (handler) {
      handler(0, 0);
    }
    return;
  }

  __block int complete = 0;
  for (TKMProgress *p in progress) {
    [_client
        sendProgress:p
             handler:^(NSError *_Nullable error) {
               if (error) {
                 [self logError:error];

                 if ([error.domain isEqual:kTKMClientErrorDomain] && error.code == 401) {
                   [self postNotificationOnMainThread:kLocalCachingClientUnauthorizedNotification];
                 }

                 // Drop the data if the server is clearly telling us our data is invalid and
                 // cannot be accepted. This most commonly happens when doing reviews before
                 // progress from elsewhere has synced, leaving the app trying to report
                 // progress on reviews you already did elsewhere.
                 if ([error.domain isEqual:kTKMClientErrorDomain] && error.code == 422) {
                   [self clearPendingProgress:p];
                 }
               } else {
                 [self clearPendingProgress:p];
               }
               complete++;
               if (handler) {
                 handler(complete, total);
               }
             }];
  }
}

- (void)clearPendingProgress:(TKMProgress *)p {
  // Delete the local pending progress.
  [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
    CheckUpdate(db, @"DELETE FROM pending_progress WHERE id = ?", @(p.assignment.subjectId));
  }];
  [self invalidateCachedPendingProgress];
}

#pragma mark - Send study materials

- (void)updateStudyMaterial:(TKMStudyMaterials *)material {
  [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
    // Store the study material locally.
    CheckUpdate(db,
                @"REPLACE INTO study_materials (id, pb) VALUES(?, ?)",
                @(material.subjectId),
                material.data);
    CheckUpdate(db, @"REPLACE INTO pending_study_materials (id) VALUES(?)", @(material.subjectId));
  }];
  [self invalidateCachedPendingStudyMaterials];

  [self sendPendingStudyMaterial:material handler:nil];
}

- (void)sendAllPendingStudyMaterials:(PartialCompletionHandler)handler {
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    __block int total = 0;
    __block int complete = 0;

    FMResultSet *results = [db
        executeQuery:
            @"SELECT s.pb FROM study_materials AS s, pending_study_materials AS p ON s.id = p.id"];
    while ([results next]) {
      TKMStudyMaterials *material = [TKMStudyMaterials parseFromData:[results dataForColumnIndex:0]
                                                               error:nil];
      NSLog(@"Sending pending study material update %@", [material description]);

      total++;
      [self sendPendingStudyMaterial:material
                             handler:^{
                               complete++;
                               handler(complete, total);
                             }];
    }

    if (!total && handler) {
      handler(0, 0);
    }
  }];
}

- (void)sendPendingStudyMaterial:(TKMStudyMaterials *)material
                         handler:(CompletionHandler _Nullable)handler {
  [_client updateStudyMaterial:material
                       handler:^(NSError *_Nullable error) {
                         if (error) {
                           [self logError:error];
                         } else {
                           [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
                             CheckUpdate(db,
                                         @"DELETE FROM pending_study_materials WHERE id = ?",
                                         @(material.subjectId));
                           }];
                           [self invalidateCachedPendingStudyMaterials];
                         }
                         if (handler) {
                           handler();
                         }
                       }];
}

#pragma mark - Sync

- (void)syncWithProgressHandler:(SyncProgressHandler)syncProgressHandler quick:(bool)quick {
  if (!_reachability.isReachable) {
    [self invalidateCachedAvailableSubjectCounts];
    syncProgressHandler(1.0);
    return;
  }

  dispatch_async(_queue, ^{
    if (_busy) {
      return;
    }
    _busy = true;

    if (!quick) {
      // Clear the sync table before doing anything else.  This forces us to re-download all
      // assignments.
      [_db inTransaction:^(FMDatabase *_Nonnull db, BOOL *_Nonnull rollback) {
        CheckUpdate(db, @"UPDATE sync SET assignments_updated_after = \"\";");
      }];
    }

    SyncProgressTracker *tracker =
        [[SyncProgressTracker alloc] initWithProgressHandler:syncProgressHandler taskCount:6];

    dispatch_group_t sendGroup = dispatch_group_create();
    [self sendAllPendingProgress:[tracker newTaskInGroup:sendGroup]];
    [self sendAllPendingStudyMaterials:[tracker newTaskInGroup:sendGroup]];

    dispatch_group_notify(sendGroup, _queue, ^{
      dispatch_group_t updateGroup = dispatch_group_create();
      [self updateAssignments:[tracker newTaskInGroup:updateGroup]];
      [self updateStudyMaterials:[tracker newTaskInGroup:updateGroup]];
      [self updateUserInfo:[tracker newTaskInGroup:updateGroup]];
      [self updateLevelProgression:[tracker newTaskInGroup:updateGroup]];

      dispatch_group_notify(updateGroup, dispatch_get_main_queue(), ^{
        _busy = false;
        [self invalidateCachedAvailableSubjectCounts];
        [self invalidateCachedSrsLevelCounts];
        [self postNotificationOnMainThread:kLocalCachingClientUserInfoChangedNotification];
      });
    });
  });
}

- (void)updateAssignments:(PartialCompletionHandler)handler {
  // Get the last assignment update time.
  __block NSString *lastDate;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    lastDate = [db stringForQuery:@"SELECT assignments_updated_after FROM sync"];
  }];

  NSLog(@"Getting all assignments modified after %@", lastDate);
  [_client getAssignmentsModifiedAfter:lastDate
                       progressHandler:handler
                               handler:^(NSError *error, NSArray<TKMAssignment *> *assignments) {
                                 if (error) {
                                   [self logError:error];
                                   return;
                                 }

                                 NSString *date = Client.currentISO8601Date;
                                 [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                                   for (TKMAssignment *assignment in assignments) {
                                     CheckUpdate(db,
                                                 @"REPLACE INTO assignments (id, pb, subject_id) "
                                                 @"VALUES (?, ?, ?)",
                                                 @(assignment.id_p), assignment.data,
                                                 @(assignment.subjectId));
                                     CheckUpdate(db,
                                                 @"REPLACE INTO subject_progress (id, level, "
                                                 @"srs_stage, subject_type) VALUES (?, ?, ?, ?)",
                                                 @(assignment.subjectId), @(assignment.level),
                                                 @(assignment.srsStage), @(assignment.subjectType));
                                   }
                                   CheckUpdate(
                                       db, @"UPDATE sync SET assignments_updated_after = ?", date);
                                 }];
                                 NSLog(@"Recorded %lu new assignments at %@",
                                       (unsigned long)assignments.count,
                                       date);
                               }];
}

- (void)updateStudyMaterials:(PartialCompletionHandler)handler {
  // Get the last study materials update time.
  __block NSString *lastDate;
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    lastDate = [db stringForQuery:@"SELECT study_materials_updated_after FROM sync"];
  }];

  NSLog(@"Getting all study materials modified after %@", lastDate);
  [_client
      getStudyMaterialsModifiedAfter:lastDate
                     progressHandler:handler
                             handler:^(NSError *error,
                                       NSArray<TKMStudyMaterials *> *studyMaterials) {
                               if (error) {
                                 [self logError:error];
                               } else {
                                 NSString *date = Client.currentISO8601Date;
                                 [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                                   for (TKMStudyMaterials *studyMaterial in studyMaterials) {
                                     CheckUpdate(
                                         db, @"REPLACE INTO study_materials (id, pb) VALUES (?, ?)",
                                         @(studyMaterial.subjectId), studyMaterial.data);
                                   }
                                   CheckUpdate(db,
                                               @"UPDATE sync SET study_materials_updated_after = ?",
                                               date);
                                 }];
                                 NSLog(@"Recorded %lu new study materials at %@",
                                       (unsigned long)studyMaterials.count,
                                       date);
                               }
                             }];
}

- (void)updateUserInfo:(PartialCompletionHandler)handler {
  [_client getUserInfo:^(NSError *_Nullable error, TKMUser *_Nullable user) {
    if (error) {
      if ([error.domain isEqual:kTKMClientErrorDomain] && error.code == 401) {
        [self postNotificationOnMainThread:kLocalCachingClientUnauthorizedNotification];
      }
      [self logError:error];
    } else {
      [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
        CheckUpdate(db, @"REPLACE INTO user (id, pb) VALUES (0, ?)", user.data);
      }];
      NSLog(@"Got user info: %@", user);
    }

    handler(1, 1);
  }];
}

- (void)updateLevelProgression:(PartialCompletionHandler)handler {
  [_client getLevelTimes:^(NSError *_Nullable error, NSArray<TKMLevel *> *levels) {
    if (error) {
      [self logError:error];
    } else {
      [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (TKMLevel *level in levels) {
          CheckUpdate(db, @"REPLACE INTO level_progressions (id, level, pb) VALUES (?, ?, ?)",
                      @(level.id_p), @(level.level), level.data);
        }
        NSLog(@"Recorded %lu level progressions", (unsigned long)levels.count);
      }];
    }

    handler(1, 1);
  }];
}

- (void)clearAllData {
  [_db inDatabase:^(FMDatabase *_Nonnull db) {
    CheckExecuteStatements(db, @(kClearAllData));
    NSLog(@"Database reset");
  }];
}

- (void)clearAllDataAndClose {
  [self clearAllData];
  [_db close];
}

@end

NS_ASSUME_NONNULL_END
