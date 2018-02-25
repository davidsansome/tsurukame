#import "LocalCachingClient.h"

#import "FMDB/FMDB.h"

NS_ASSUME_NONNULL_BEGIN

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

NSNotificationName kLocalCachingClientBusyChangedNotification =
    @"kLocalCachingClientBusyChangedNotification";

@interface LocalCachingClient ()

@property(nonatomic, getter=isBusy) bool busy;

@end

@implementation LocalCachingClient {
  Client *_client;
  Reachability *_reachability;
  FMDatabaseQueue *_db;
  dispatch_queue_t _queue;
}

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability {
  self = [super init];
  if (self) {
    _client = client;
    _reachability = reachability;
    _db = [self openDatabase];
    assert(_db);
    _queue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0);
  }
  return self;
}

- (FMDatabaseQueue *)openDatabase {
  NSArray *paths =
  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *fileName = [NSString stringWithFormat:@"%@/local-cache.db", paths[0]];
  
  NSLog(@"Opening database %@", fileName);
  FMDatabaseQueue *ret = [FMDatabaseQueue databaseQueueWithPath:fileName];

  static NSArray<NSString *> *kSchemas;
  static dispatch_once_t once;
  dispatch_once(&once, ^(void) {
    kSchemas = @[
      @"CREATE TABLE sync ("
      "  assignments_updated_after TEXT,"
      "  study_materials_updated_after TEXT"
      ");"
      "INSERT INTO sync ("
      "  assignments_updated_after,"
      "  assignments_updated_after"
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
      ");",
      @"CREATE TABLE pending_study_materials ("
      "  id INTEGER PRIMARY KEY"
      ");"
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

- (void)setBusy:(bool)busy {
  if (busy == _busy) {
    return;
  }
  _busy = busy;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kLocalCachingClientBusyChangedNotification object:self];
  });
}

- (NSArray<WKAssignment *> *)getAllAssignments {
  NSMutableArray<WKAssignment *> *ret = [NSMutableArray array];
  
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    FMResultSet *r = [db executeQuery:@"SELECT pb FROM assignments"];
    while ([r next]) {
      NSError *error = nil;
      WKAssignment *assignment = [WKAssignment parseFromData:[r dataForColumnIndex:0] error:&error];
      if (error) {
        [self.delegate localCachingClientDidReportError:error];
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

- (void)sendProgress:(NSArray<WKProgress *> *)progress
             handler:(ProgressHandler _Nullable)handler {
  [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
    for (WKProgress *p in progress) {
      // Delete the assignment.
      CheckUpdate(db, @"DELETE FROM assignments WHERE id = ?", @(p.assignmentId));
      
      // Store the progress locally.
      CheckUpdate(db, @"REPLACE INTO pending_progress (id, pb) VALUES(?, ?)",
                  @(p.subjectId), p.data);
    }
  }];
  
  [self sendPendingProgress:progress handler:^{
    if (handler) {
      handler(nil);
    }
  }];
}

- (void)sendAllPendingProgress:(void (^)(void))handler {
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
                    handler:(void (^)(void))handler {
  [_client sendProgress:progress handler:^(NSError * _Nullable error) {
    if (error) {
      [self.delegate localCachingClientDidReportError:error];
    } else {
      // Delete the local pending progress.
      [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (WKProgress *p in progress) {
          CheckUpdate(db, @"DELETE FROM pending_progress WHERE id = ?", @(p.subjectId));
        }
      }];
    }
    handler();
  }];
}

- (void)sendAllPendingStudyMaterials:(void (^)(void))handler {
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

- (void)sendPendingStudyMaterial:(WKStudyMaterials *)material handler:(void (^)(void))handler {
  [_client updateStudyMaterial:material handler:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"Failed to send study material update: %@", error);
    } else {
      [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        CheckUpdate(db, @"DELETE FROM pending_study_materials WHERE id = ?", @(material.subjectId));
      }];
    }
    handler();
  }];
}

- (void)updateStudyMaterial:(WKStudyMaterials *)material
                    handler:(UpdateStudyMaterialHandler _Nullable)handler {
  [_db inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
    // Store the study material locally.
    CheckUpdate(db, @"REPLACE INTO study_materials (id, pb) VALUES(?, ?)", @(material.subjectId), material.data);
    CheckUpdate(db, @"REPLACE INTO pending_study_materials (id) VALUES(?)", @(material.subjectId));
  }];
  
  [self sendPendingStudyMaterial:material handler:^{
    if (handler) {
      handler(nil);
    }
  }];
}

- (void)update {
  if (!_reachability.isReachable) {
    return;
  }
  
  dispatch_async(_queue, ^{
    @synchronized(self) {
      if (self.isBusy) {
        return;
      }
      self.busy = true;
    }
    
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
        @synchronized(self) {
          self.busy = false;
        }
      });
    });
  });
}

- (NSDate *)lastUpdated {
  __block NSDate *ret = nil;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    ret = [_client.dateFormatter
           dateFromString:[db stringForQuery:@"SELECT assignments_updated_after FROM sync"]];
  }];
  return ret;
}

- (void)updateAssignments:(void (^)(void))handler {
  // Get the last assignment update time.
  __block NSString *lastDate;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    lastDate = [db stringForQuery:@"SELECT assignments_updated_after FROM sync"];
  }];
  
  NSLog(@"Getting all assignments modified after %@", lastDate);
  [_client getAssignmentsModifiedAfter:lastDate
                               handler:^(NSError *error, NSArray<WKAssignment *> *assignments) {
                                 if (error) {
                                   [self.delegate localCachingClientDidReportError:error];
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

- (void)updateStudyMaterials:(void (^)(void))handler {
  // Get the last study materials update time.
  __block NSString *lastDate;
  [_db inDatabase:^(FMDatabase * _Nonnull db) {
    lastDate = [db stringForQuery:@"SELECT study_materials_updated_after FROM sync"];
  }];
  
  NSLog(@"Getting all study materials modified after %@", lastDate);
  [_client getStudyMaterialsModifiedAfter:lastDate
                                 handler:^(NSError *error, NSArray<WKStudyMaterials *> *studyMaterials) {
                                   if (error) {
                                     [self.delegate localCachingClientDidReportError:error];
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

- (void)updateUserInfo:(void (^)(void))handler {
  [_client getUserInfo:^(NSError * _Nullable error, WKUser * _Nullable user) {
    if (error) {
      [self.delegate localCachingClientDidReportError:error];
    } else {
      [_db inTransaction:^(FMDatabase *db, BOOL *rollback) {
        CheckUpdate(db, @"REPLACE INTO user (id, pb) VALUES (0, ?)", user.data);
      }];
      NSLog(@"Got user info: %@", user);
    }
    handler();
  }];
}

@end

NS_ASSUME_NONNULL_END
