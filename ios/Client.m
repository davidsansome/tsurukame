#import "Client.h"

NS_ASSUME_NONNULL_BEGIN

static const char *kURLBase = "https://www.wanikani.com/api/v2";
static const char *kProgressURL = "https://www.wanikani.com/json/progress";
static const char *kReviewSessionURL = "https://www.wanikani.com/review/session";

NSErrorDomain WKClientErrorDomain = @"WKClientErrorDomain";

static NSError *MakeError(int code, NSString *msg) {
  return [NSError errorWithDomain:WKClientErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey:msg}];
}

static const NSTimeInterval kProgressTokenValidity = 2 * 60 * 60;  // 2 hours.
static NSRegularExpression *kProgressTokenRE;

typedef void(^PartialResponseHandler)(NSArray * _Nullable data, NSError * _Nullable error);

@implementation Client {
  NSString *_apiToken;
  NSString *_cookie;
  NSURLSession *_urlSession;
  NSDateFormatter *_dateFormatter;
  NSString *_progressToken;
  NSDate *_progressTokenUpdated;
}

- (instancetype)initWithApiToken:(NSString *)apiToken
                          cookie:(NSString *)cookie {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kProgressTokenRE = [NSRegularExpression regularExpressionWithPattern:
                        @"<meta name=\"csrf-token\" content=\"([^\"]*)" options:0 error:nil];
  });
  
  if (self = [super init]) {
    _apiToken = apiToken;
    _cookie = cookie;
    _urlSession = [NSURLSession sharedSession];
    _dateFormatter = [[NSDateFormatter alloc] init];
    _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
    _dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
  }
  return self;
}

#pragma mark - Authorization

- (NSMutableURLRequest *)authorizeAPIRequest:(NSURL *)url {
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"Token token=%@", _apiToken]
      forHTTPHeaderField:@"Authorization"];
  return req;
}

- (NSMutableURLRequest *)authorizeUserRequest:(NSURL *)url {
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"_wanikani_session=%@", _cookie]
       forHTTPHeaderField:@"Cookie"];
  return req;
}

#pragma mark - Query utilities

- (void)startPagedQueryFor:(NSURL *)url
                   handler:(PartialResponseHandler)handler {
  NSURLRequest *req = [self authorizeAPIRequest:url];
  NSLog(@"Request: %@", url);
  NSURLSessionDataTask *task =
      [_urlSession dataTaskWithRequest:req
                     completionHandler:^(NSData * _Nullable data,
                                         NSURLResponse * _Nullable response,
                                         NSError * _Nullable error) {
    [self parseJsonResponse:data
                      error:error
                    handler:handler];
  }];
  [task resume];
}

- (NSString *)currentISO8601Time {
  return [_dateFormatter stringFromDate:[NSDate date]];
}

- (void)parseJsonResponse:(NSData *)data
                    error:(NSError *)error
                  handler:(PartialResponseHandler)handler {
  if (error != nil) {
    handler(nil, error);
    return;
  }
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (error != nil) {
    handler(nil, error);
    return;
  }
  if (dict[@"error"] != nil) {
    handler(nil, MakeError(0, dict[@"error"]));
    return;
  }
  
  handler(dict[@"data"], nil);
  
  // Get the next page if we have one.
  if (dict[@"pages"][@"next_url"] != [NSNull null]) {
    NSString *nextURLString = dict[@"pages"][@"next_url"];
    NSLog(@"Request: %@", nextURLString);
    NSURLRequest *req = [self authorizeAPIRequest:[NSURL URLWithString:nextURLString]];
    NSURLSessionDataTask *task =
        [_urlSession dataTaskWithRequest:req
                      completionHandler:^(NSData * _Nullable data,
                                          NSURLResponse * _Nullable response,
                                          NSError * _Nullable error) {
      [self parseJsonResponse:data 
                        error:error
                      handler:handler];
    }];
    [task resume];
  } else {
    handler(nil, nil);
  }
}

#pragma mark - Assignments

- (void)getAssignmentsModifiedAfter:(NSString *)date
                            handler:(AssignmentHandler)handler {
  NSMutableArray<WKAssignment *> *ret = [NSMutableArray array];

  NSURLComponents *url =
      [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%s/assignments",
                                             kURLBase]];
  if (date && date.length) {
    [url setQueryItems:@[
        [NSURLQueryItem queryItemWithName:@"updated_after" value:date],
    ]];
  }
  
  [self startPagedQueryFor:url.URL handler:^(NSArray *data, NSError *error) {
    if (error) {
      handler(error, nil);
      return;
    } else if (!data) {
      handler(nil, ret);
      return;
    }
    
    for (NSDictionary *d in data) {
      WKAssignment *assignment = [[WKAssignment alloc] init];
      assignment.id_p = [d[@"id"] intValue];
      assignment.level = [d[@"data"][@"level"] intValue];
      assignment.subjectId = [d[@"data"][@"subject_id"] intValue];
      assignment.srsStage = [d[@"data"][@"srs_stage"] intValue];
      
      if (d[@"data"][@"available_at"] != [NSNull null]) {
        assignment.availableAt =
            [[_dateFormatter dateFromString:d[@"data"][@"available_at"]] timeIntervalSince1970];
      }
      
      if (d[@"data"][@"started_at"] != [NSNull null]) {
        assignment.startedAt =
            [[_dateFormatter dateFromString:d[@"data"][@"started_at"]] timeIntervalSince1970];
      }
      
      NSString *subjectType = d[@"data"][@"subject_type"];
      if ([subjectType isEqualToString:@"radical"]) {
        assignment.subjectType = WKSubject_Type_Radical;
      } else if ([subjectType isEqualToString:@"kanji"]) {
        assignment.subjectType = WKSubject_Type_Kanji;
      } else if ([subjectType isEqualToString:@"vocabulary"]) {
        assignment.subjectType = WKSubject_Type_Vocabulary;
      } else {
        NSAssert(false, @"Unknown subject type %@", subjectType);
      }
      [ret addObject:assignment];
    }
  }];
}

#pragma mark - Progress

- (void)fetchProgressToken:(ProgressHandler)handler {
  NSURLRequest *req = [self authorizeUserRequest:[NSURL URLWithString:@(kReviewSessionURL)]];
  NSURLSessionDataTask *task =
    [_urlSession dataTaskWithRequest:req
                   completionHandler:^(NSData * _Nullable data,
                                       NSURLResponse * _Nullable response,
                                       NSError * _Nullable error) {
    if (error != nil) {
      handler(error);
      return;
    }
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
      handler(MakeError((int)httpResponse.statusCode,
                        [NSString stringWithFormat:@"HTTP error %ld for %@",
                         (long)httpResponse.statusCode,
                         response.URL.absoluteString]));
      return;
    }
                                        
    NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSTextCheckingResult *result = [kProgressTokenRE firstMatchInString:body
                                                                options:0
                                                                  range:NSMakeRange(0, body.length)];
    if (!result || result.range.location == NSNotFound) {
      NSLog(@"Page contents: %@", body);
      handler(MakeError(0, @"Progress token not found in page"));
      return;
    }
                                                  
    _progressToken = [body substringWithRange:[result rangeAtIndex:1]];
    _progressTokenUpdated = [NSDate date];
    NSLog(@"Got progress token %@", _progressToken);
    handler(nil);
  }];
  [task resume];
}

- (bool)isProgressTokenValid {
  return _progressToken.length &&
      - [_progressTokenUpdated timeIntervalSinceNow] < kProgressTokenValidity;
}

- (void)sendProgress:(NSArray<WKProgress *> *)progress
             handler:(ProgressHandler)handler {
  void (^makeRequest)() = ^() {
    // Encode the data to send in the request.
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *obj = [NSMutableDictionary dictionary];
    for (WKProgress *p in progress) {
      obj[[@(p.id_p) stringValue]] = @[ [@(p.meaningWrong ? 1 : 0) stringValue],
                                        [@(p.readingWrong ? 1 : 0) stringValue] ];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    
    // Add the CSRF token and the data to the request.
    NSMutableURLRequest *req = [self authorizeUserRequest:[NSURL URLWithString:@(kReviewSessionURL)]];
    [req addValue:_progressToken forHTTPHeaderField:@"X-CSRF-Token"];
    req.HTTPMethod = @"PUT";
    req.HTTPBody = data;

    // Start the request.
    NSLog(@"PUT %@ to %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], req.URL);
    NSURLSessionDataTask *task =
      [_urlSession dataTaskWithRequest:req
                     completionHandler:^(NSData * _Nullable data,
                                         NSURLResponse * _Nullable response,
                                         NSError * _Nullable error) {
        handler(error);
    }];
    [task resume];
  };

  // Fetch a new progress token if it's invalid or expired.
  if ([self isProgressTokenValid]) {
    makeRequest();
  } else {
    [self fetchProgressToken:^(NSError *error) {
      if (error != nil) {
        handler(error);
      } else {
        makeRequest();
      }
    }];
  }
}

@end

NS_ASSUME_NONNULL_END
