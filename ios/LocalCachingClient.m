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
    _queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    
    if (_reachability.isReachable) {
      [self update];
    }
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
      "INSERT INTO sync (assignments_updated_after) VALUES (\"\");"
      "CREATE TABLE assignments ("
      "  id INTEGER PRIMARY KEY,"
      "  pb BLOB"
      ");"
      "CREATE TABLE pending_progress ("
      "  id INTEGER PRIMARY KEY,"
      "  wrong_meanings INTEGER,"
      "  wrong_readings INTEGER"
      ");"
      "CREATE TABLE study_materials ("
      "  id INTEGER PRIMARY KEY,"
      "  pb BLOB"
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

- (void)getAllAssignments:(AssignmentHandler)handler {
  dispatch_async(_queue, ^{
    NSMutableArray<WKAssignment *> *ret = [NSMutableArray array];
    __block NSError *err = nil;
    
    [_db inDatabase:^(FMDatabase * _Nonnull db) {
      FMResultSet *r = [db executeQuery:@"SELECT pb FROM assignments"];
      while ([r next]) {
        WKAssignment *assignment = [WKAssignment parseFromData:[r dataForColumnIndex:0] error:&err];
        if (err) {
          [self.delegate localCachingClientDidReportError:err];
          return;
        }
        [ret addObject:assignment];
      }
    }];
    handler(err, ret);
  });
}

- (void)getStudyMaterialForID:(int)subjectID handler:(StudyMaterialHandler)handler {
  dispatch_async(_queue, ^{
    [_db inDatabase:^(FMDatabase * _Nonnull db) {
      FMResultSet *r = [db executeQuery:@"SELECT pb FROM study_materials WHERE id = ?", @(subjectID)];
      while ([r next]) {
        WKStudyMaterials *studyMaterials =
            [WKStudyMaterials parseFromData:[r dataForColumnIndex:0] error:nil];
        handler(studyMaterials);
        [r close];
        return;
      }
      handler(nil);
    }];
  });
}

- (void)sendProgress:(NSArray<WKProgress *> *)progress handler:(ProgressHandler)handler {
  // TODO: store locally.
  [_client sendProgress:progress handler:handler];
}

- (void)update {
  dispatch_async(_queue, ^{
    @synchronized(self) {
      if (self.isBusy) {
        return;
      }
      self.busy = true;
    }
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    dispatch_group_enter(dispatchGroup);
    [self updateAssignments:^{
      dispatch_group_leave(dispatchGroup);
    }];
    dispatch_group_enter(dispatchGroup);
    [self updateStudyMaterials:^{
      dispatch_group_leave(dispatchGroup);
    }];
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
      @synchronized(self) {
        self.busy = false;
      }
    });
  });
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
  
  NSLog(@"Getting all assignments modified after %@", lastDate);
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

@end

NS_ASSUME_NONNULL_END
