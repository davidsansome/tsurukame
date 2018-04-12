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

#import "LocalCachingClient.h"

#import "proto/Wanikani+Convenience.h"
#import "third_party/FMDB/FMDB.h"

NS_ASSUME_NONNULL_BEGIN

NSNotificationName kLocalCachingClientAvailableItemsChangedNotification =
    @"kLocalCachingClientAvailableItemsChangedNotification";
NSNotificationName kLocalCachingClientPendingItemsChangedNotification = 
    @"kLocalCachingClientPendingItemsChangedNotification";

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

static const char *kClearAllData = 
    "UPDATE sync SET"
    "  assignments_updated_after = \"\","
    "  study_materials_updated_after = \"\""
    ";"
    "DELETE FROM assignments;"
    "DELETE FROM pending_progress;"
    "DELETE FROM study_materials;"
    "DELETE FROM user;"
    "DELETE FROM pending_study_materials;";

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


@implementation LocalCachingClient {
  Client *_client;
  Reachability *_reachability;
  FMDatabaseQueue *_db;
  dispatch_queue_t _queue;
  bool _busy;

  int _cachedAvailableLessonCount;
  int _cachedAvailableReviewCount;
  NSArray<NSNumber *> *_cachedUpcomingReviews;
  NSArray<WKAssignment *> *_cachedMaxLevelAssignments;
  int _cachedPendingProgress;
  int _cachedPendingStudyMaterials;
  bool _isCachedAvailableSubjectCountsStale;
  bool _isCachedPendingProgressStale;
  bool _isCachedPendingStudyMaterialsStale;
}

#pragma mark - Initialisers

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability {
  self = [super init];
  if (self) {
    _client = client;
    _reachability = reachability;
    _db = [self openDatabase];
    assert(_db);
    _queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);

    _isCachedAvailableSubjectCountsStale = true;
    _isCachedPendingProgressStale = true;
    _isCachedPendingStudyMaterialsStale = true;
  }
  return self;
}

- (FMDatabaseQueue *)openDatabase {
  NSArray *paths =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *fileName = [NSString stringWithFormat:@"%@/local-cache.db", paths[0]];
  
  FMDatabaseQueue *ret = [FMDatabaseQueue databaseQueueWithPath:fileName];

  static NSArray<NSString *> *kSchemas;
  static dispatch_once_t once;
  dispatch_once(&once, ^(void) {
    kSchemas = @[
      @(kSchemaV1),
    ];
  });
  
  [ret inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
    // Get the current version.
    NSUInteger targetVersion = kSchemas.count;
    NSUInteger currentVersion = db.userVersion;
    if (currentVersion == targetVersion) {
      NSLog(@"Database up to date (version %lu)", (unsigned long)currentVersion);
      return;
    }
    for (; currentVersion < targetVersion; ++currentVersion) {
      CheckExecuteStatements(db, kSchemas[currentVersion]);
    }
    CheckUpdate(db, [NSString stringWithFormat:@"PRAGMA user_version = %lu", (unsigned long)targetVersion]);
    NSLog(@"Database updated to schema %lu", targetVersion);
  }];
  return ret;
}

#pragma mark - Local database getters

- (NSArray<WKAssignment *> *)getAllAssignments {
  NSMutableArray<WKAssignment *> *ret = [NSMutableArray array];
  
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM assignments"];
    while ([r next]) {
      NSError *error = nil;
      WKAssignment *assignment = [WKAssignment parseFromData:[r dataForColumnIndex:0] error:&error];
      if (error) {
        NSLog(@"Parsing WKAssignment failed: %@", error);
        return;
      }
      [ret addObject:assignment];
    }
  }];
  return ret;
}

- (WKStudyMaterials * _Nullable)getStudyMaterialForID:(int)subjectID {
  __block WKStudyMaterials *ret = nil;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM study_materials WHERE id = ?", @(subjectID)];
    while ([r next]) {
      ret = [WKStudyMaterials parseFromData:[r dataForColumnIndex:0] error:nil];
    }
  }];
  return ret;
}

- (WKUser * _Nullable)getUserInfo {
  __block WKUser *ret = nil;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM user"];
    while ([r next]) {
      ret = [WKUser parseFromData:[r dataForColumnIndex:0] error:nil];
    }
  }];
  return ret;
}

- (int)countRowsInTable:(NSString *)tableName {
  __block int ret = 0;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    NSString *sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", tableName];
    FMResultSet *r = [db executeQuery:sql];
    while ([r next]) {
      ret = [r intForColumnIndex:0];
    }
  }];
  return ret;
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
  @synchronized(self) {
    if (_isCachedAvailableSubjectCountsStale) {
      [self updateAvailableSubjectCounts];
      _isCachedAvailableSubjectCountsStale = false;
    }
    return _cachedAvailableReviewCount;
  }
}

- (int)availableLessonCount {
  @synchronized(self) {
    if (_isCachedAvailableSubjectCountsStale) {
      [self updateAvailableSubjectCounts];
      _isCachedAvailableSubjectCountsStale = false;
    }
    return _cachedAvailableLessonCount;
  }
}

- (NSArray<NSNumber *> *)upcomingReviews {
  @synchronized(self) {
    if (_isCachedAvailableSubjectCountsStale) {
      [self updateAvailableSubjectCounts];
      _isCachedAvailableSubjectCountsStale = false;
    }
    return _cachedUpcomingReviews;
  }
}

- (NSArray<WKAssignment *> *)maxLevelAssignments {
  @synchronized(self) {
    if (_isCachedAvailableSubjectCountsStale) {
      [self updateAvailableSubjectCounts];
      _isCachedAvailableSubjectCountsStale = false;
    }
    return _cachedMaxLevelAssignments;
  }
}

- (void)updateAvailableSubjectCounts {
  NSArray<WKAssignment *> *assignments = [self getAllAssignments];
  int lessons = 0;
  int reviews = 0;
  
  NSDate *now = [NSDate date];
  
  NSMutableArray<NSNumber *> *upcomingReviews = [NSMutableArray arrayWithCapacity:48];
  for (int i = 0; i < 24; i++) {
    [upcomingReviews addObject:@(0)];
  }
  
  int maxLevel = 0;
  NSMutableArray<WKAssignment *> *maxLevelAssignments = [NSMutableArray array];
  
  for (WKAssignment *assignment in assignments) {
    if (assignment.level > maxLevel) {
      [maxLevelAssignments removeAllObjects];
      maxLevel = assignment.level;
    }
    if (assignment.level == maxLevel) {
      [maxLevelAssignments addObject:assignment];
    }
    
    if (assignment.isLessonStage) {
      lessons ++;
    } else if (assignment.isReviewStage) {
      NSTimeInterval availableInSeconds = [assignment.availableAtDate timeIntervalSinceDate:now];
      if (availableInSeconds <= 0) {
        reviews ++;
        continue;
      }
      int availableInHours = availableInSeconds / (60 * 60);
      if (availableInHours < upcomingReviews.count) {
        [upcomingReviews setObject:[NSNumber numberWithInt:[upcomingReviews[availableInHours] intValue] + 1]
                atIndexedSubscript:availableInHours];
      }
    }
  }

  NSLog(@"Recalculated available items");
  _cachedAvailableLessonCount = lessons;
  _cachedAvailableReviewCount = reviews;
  _cachedUpcomingReviews = upcomingReviews;
  _cachedMaxLevelAssignments = maxLevelAssignments;
}

#pragma mark - Invalidating cached data

- (void)postNotificationOnMainThread:(NSNotificationName)name {
  NSLog(@"Posting on main thread: %@", name);
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

#pragma mark - Send progress

- (void)sendProgress:(NSArray<WKProgress *> *)progress {
  [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
    for (WKProgress *p in progress) {
      // Delete the assignment.
      CheckUpdate(db, @"DELETE FROM assignments WHERE id = ?", @(p.assignmentId));
      
      // Store the progress locally.
      CheckUpdate(db, @"REPLACE INTO pending_progress (id, pb) VALUES(?, ?)",
                  @(p.subjectId), p.data);
    }
  }];
  [self invalidateCachedPendingProgress];
  [self invalidateCachedAvailableSubjectCounts];
  
  [self sendPendingProgress:progress handler:nil];
}

- (void)sendAllPendingProgress:(CompletionHandler)handler {
  NSMutableArray<WKProgress *> *progress = [NSMutableArray array];
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    FMResultSet *results = [db executeQuery:@"SELECT pb FROM pending_progress"];
    while ([results next]) {
      [progress addObject:[WKProgress parseFromData:[results dataForColumnIndex:0] error:nil]];
    }
  }];
  [self sendPendingProgress:progress handler:handler];
}

- (void)sendPendingProgress:(NSArray<WKProgress *> *)progress
                    handler:(CompletionHandler _Nullable)handler {
  [_client sendProgress:progress handler:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"sendProgress failed: %@", error);
    } else {
      // Delete the local pending progress.
      [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKProgress *p in progress) {
          CheckUpdate(db, @"DELETE FROM pending_progress WHERE id = ?", @(p.subjectId));
        }
      }];
      [self invalidateCachedPendingProgress];
    }
    if (handler) {
      handler();
    }
  }];
}

#pragma mark - Send study materials

- (void)updateStudyMaterial:(WKStudyMaterials *)material {
  [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
    // Store the study material locally.
    CheckUpdate(db, @"REPLACE INTO study_materials (id, pb) VALUES(?, ?)", @(material.subjectId), material.data);
    CheckUpdate(db, @"REPLACE INTO pending_study_materials (id) VALUES(?)", @(material.subjectId));
  }];
  [self invalidateCachedPendingStudyMaterials];
  
  [self sendPendingStudyMaterial:material handler:nil];
}

- (void)sendAllPendingStudyMaterials:(CompletionHandler)handler {
  dispatch_group_t dispatchGroup = dispatch_group_create();
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    FMResultSet *results = [db executeQuery:@"SELECT s.pb FROM study_materials AS s, pending_study_materials AS p ON s.id = p.id"];
    while ([results next]) {
      WKStudyMaterials *material = [WKStudyMaterials parseFromData:[results dataForColumnIndex:0] error:nil];
      NSLog(@"Sending pending study material update %@", [material description]);
      
      dispatch_group_enter(dispatchGroup);
      [self sendPendingStudyMaterial:material handler:^{
        dispatch_group_leave(dispatchGroup);
      }];
    }
  }];
  
  dispatch_group_notify(dispatchGroup, _queue, handler);
}

- (void)sendPendingStudyMaterial:(WKStudyMaterials *)material
                         handler:(CompletionHandler _Nullable)handler {
  [_client updateStudyMaterial:material handler:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"Failed to send study material update: %@", error);
    } else {
      [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        CheckUpdate(db, @"DELETE FROM pending_study_materials WHERE id = ?", @(material.subjectId));
      }];
      [self invalidateCachedPendingStudyMaterials];
    }
    if (handler) {
      handler();
    }
  }];
}

#pragma mark - Sync

- (void)sync:(CompletionHandler _Nullable)completionHandler {
  if (!_reachability.isReachable) {
    if (completionHandler) {
      completionHandler();
    }
    return;
  }
  
  dispatch_async(_queue, ^{
    if (_busy) {
      if (completionHandler) {
        completionHandler();
      }
      return;
    }
    _busy = true;
    
    dispatch_group_t sendGroup = dispatch_group_create();

    dispatch_group_enter(sendGroup);
    [self sendAllPendingProgress:^{
      dispatch_group_leave(sendGroup);
    }];
    dispatch_group_enter(sendGroup);
    [self sendAllPendingStudyMaterials:^{
      dispatch_group_leave(sendGroup);
    }];
    
    dispatch_group_notify(sendGroup, _queue, ^{
      dispatch_group_t updateGroup = dispatch_group_create();
    
      dispatch_group_enter(updateGroup);
      [self updateAssignments:^{
        dispatch_group_leave(updateGroup);
      }];
      dispatch_group_enter(updateGroup);
      [self updateStudyMaterials:^{
        dispatch_group_leave(updateGroup);
      }];
      dispatch_group_enter(updateGroup);
      [self updateUserInfo:^{
        dispatch_group_leave(updateGroup);
      }];
      
      dispatch_group_notify(updateGroup, dispatch_get_main_queue(), ^{
        _busy = false;
        [self invalidateCachedAvailableSubjectCounts];
        if (completionHandler) {
          completionHandler();
        }
      });
    });
  });
}

- (void)updateAssignments:(CompletionHandler)handler {
  // Get the last assignment update time.
  __block NSString *lastDate;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    lastDate = [db stringForQuery:@"SELECT assignments_updated_after FROM sync"];
  }];
  
  NSLog(@"Getting all assignments modified after %@", lastDate);
  [_client getAssignmentsModifiedAfter:lastDate
                               handler:^(NSError *error, NSArray<WKAssignment *> *assignments) {
                                 if (error) {
                                   NSLog(@"getAssignmentsModifiedAfter failed: %@", error);
                                 } else {
                                   NSString *date = _client.currentISO8601Time;
                                   [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                                     for (WKAssignment *assignment in assignments) {
                                       CheckUpdate(db, @"REPLACE INTO assignments (id, pb) VALUES (?, ?)",
                                                   @(assignment.id_p), assignment.data);
                                     }
                                     CheckUpdate(db, @"UPDATE sync SET assignments_updated_after = ?", date);
                                   }];
                                   NSLog(@"Recorded %lu new assignments at %@", (unsigned long)assignments.count, date);
                                 }
                                 handler();
                               }];
}

- (void)updateStudyMaterials:(CompletionHandler)handler {
  // Get the last study materials update time.
  __block NSString *lastDate;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    lastDate = [db stringForQuery:@"SELECT study_materials_updated_after FROM sync"];
  }];
  
  NSLog(@"Getting all study materials modified after %@", lastDate);
  [_client getStudyMaterialsModifiedAfter:lastDate
                                 handler:^(NSError *error, NSArray<WKStudyMaterials *> *studyMaterials) {
                                   if (error) {
                                     NSLog(@"getStudyMaterialsModifiedAfter failed: %@", error);
                                   } else {
                                     NSString *date = _client.currentISO8601Time;
                                     [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
                                       for (WKStudyMaterials *studyMaterial in studyMaterials) {
                                         CheckUpdate(db, @"REPLACE INTO study_materials (id, pb) VALUES (?, ?)",
                                                     @(studyMaterial.subjectId), studyMaterial.data);
                                       }
                                       CheckUpdate(db, @"UPDATE sync SET study_materials_updated_after = ?", date);
                                     }];
                                     NSLog(@"Recorded %lu new study materials at %@", (unsigned long)studyMaterials.count, date);
                                   }
                                   handler();
                                 }];
}

- (void)updateUserInfo:(CompletionHandler)handler {
  [_client getUserInfo:^(NSError * _Nullable error, WKUser * _Nullable user) {
    if (error) {
      NSLog(@"getUserInfo failed: %@", error);
    } else {
      [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
        CheckUpdate(db, @"REPLACE INTO user (id, pb) VALUES (0, ?)", user.data);
      }];
      NSLog(@"Got user info: %@", user);
    }
    handler();
  }];
}

- (void)clearAllData {
  [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
    CheckExecuteStatements(db, @(kClearAllData));
    NSLog(@"Database reset");
  }];
}

@end

NS_ASSUME_NONNULL_END
