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

@implementation LocalCachingClient {
  Client *_client;
  Reachability *_reachability;
  bool _busy;
  FMDatabaseQueue *_db;
  dispatch_queue_t _queue;
}

- (instancetype)initWithClient:(Client *)client
                  reachability:(Reachability *)reachability {
  self = [super init];
  if (self) {
    _client = client;
    _reachability = reachability;
    _busy = false;
    _db = [self openDatabase];
    assert(_db);
    _queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    
    if (_reachability.isReachable) {
      [self update];
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(reachabilityChanged:)
               name:kReachabilityChangedNotification
             object:_reachability];
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
  dispatch_once_t once;
  dispatch_once(&once, ^(void) {
    kSchemas = @[
      @"CREATE TABLE sync ("
      "  assignments_updated_after TEXT"
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
    CheckUpdate(db, [NSString stringWithFormat:@"PRAGMA user_version = %d", targetVersion]);
    NSLog(@"Database updated to schema %lu", targetVersion);
  }];
  return ret;
}

- (void)reachabilityChanged:(NSNotification *)notification {
  NSLog(@"Reachability changed: %d", _reachability.isReachable);
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
          return;
        }
        [ret addObject:assignment];
      }
    }];
    handler(err, ret);
  });
}

- (void)update {
  dispatch_async(_queue, ^{
    @synchronized(self) {
      if (_busy) {
        return;
      }
      _busy = true;
    }
    
    // Get the last assignment update time.
    __block NSString *lastDate;
    [_db inDatabase:^(FMDatabase * _Nonnull db) {
      lastDate = [db stringForQuery:@"SELECT assignments_updated_after FROM sync"];
    }];
    
    NSLog(@"Getting all assignments modified after %@", lastDate);
    [_client getAssignmentsModifiedAfter:lastDate
                                 handler:^(NSError *error, NSArray<WKAssignment *> *assignments) {
      if (error) {
        NSLog(@"Failed to get assignments: %@", error);
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
    
      @synchronized(self) {
        _busy = false;
      }
    }];
  });
}

@end

NS_ASSUME_NONNULL_END
