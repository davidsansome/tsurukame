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

#import "Client.h"
#import "proto/Wanikani+Convenience.h"

NS_ASSUME_NONNULL_BEGIN

const char *kWanikaniSessionCookieName = "_wanikani_session";
static const char *kURLBase = "https://api.wanikani.com/v2";
static const char *kReviewProgressURL = "https://www.wanikani.com/json/progress";
static const char *kLessonProgressURL = "https://www.wanikani.com/json/lesson/completed";
static const char *kStudyMaterialsURLBase = "https://www.wanikani.com/study_materials";
static const char *kReviewSessionURL = "https://www.wanikani.com/review/session";
static const char *kAccountURL = "https://www.wanikani.com/settings/account";
static const char *kLoginURL = "https://www.wanikani.com/login";
static const char *kDashboardURL = "https://www.wanikani.com/dashboard";

static const char *kCSRFTokenREPattern = "<meta name=\"csrf-token\" content=\"([^\"]*)";
static const char *kEmailAddressREPattern = "<input[^>]+value=\"([^\"]+)\"[^>]+id=\"user_email\"";
static const char *kAPITokenREPattern = "<input[^>]+value=\"([^\"]+)\"[^>]+name=\"user_api_key_v2\"";

static NSString *const kFormDataContentType = @"application/x-www-form-urlencoded";
static NSString *const kJSONContentType = @"application/json";

NSErrorDomain const kTKMClientErrorDomain = @"kTKMClientErrorDomain";
const int kTKMLoginErrorCode = 403;

static NSError *MakeError(int code, NSString *msg) {
  return [NSError errorWithDomain:kTKMClientErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey:msg}];
}

static const NSTimeInterval kCSRFTokenValidity = 2 * 60 * 60;  // 2 hours.
static NSRegularExpression *sCSRFTokenRE;
static NSRegularExpression *sEmailAddressRE;
static NSRegularExpression *sAPITokenRE;

typedef void(^PartialResponseHandler)(id _Nullable data, NSError * _Nullable error);
typedef void(^PUTResponseHandler)(NSError * _Nullable error);

static void EnsureInitialised() {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sCSRFTokenRE = [NSRegularExpression regularExpressionWithPattern:@(kCSRFTokenREPattern)
                                                             options:0 error:nil];
    sEmailAddressRE = [NSRegularExpression regularExpressionWithPattern:@(kEmailAddressREPattern)
                                                                options:0 error:nil];
    sAPITokenRE = [NSRegularExpression regularExpressionWithPattern:@(kAPITokenREPattern)
                                                            options:0 error:nil];
  });
}

static NSString *ParseCSRFTokenFromResponse(NSData * _Nullable data,
                                            NSURLResponse * _Nullable response,
                                            NSError ** _Nullable error) {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  if (httpResponse.statusCode != 200) {
    if (error) {
      *error = MakeError((int)httpResponse.statusCode,
                         [NSString stringWithFormat:@"HTTP error %ld for %@",
                          (long)httpResponse.statusCode,
                          response.URL.absoluteString]);
    }
    return nil;
  }
  
  NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSTextCheckingResult *result = [sCSRFTokenRE firstMatchInString:body
                                                          options:0
                                                            range:NSMakeRange(0, body.length)];
  if (!result || result.range.location == NSNotFound) {
    if (error) {
      *error = MakeError(0, @"Progress token not found in page");
    }
    return nil;
  }
  
  return [body substringWithRange:[result rangeAtIndex:1]];
}

static NSData *EncodeQueryString(NSDictionary<NSString *, NSString *> *keyValues) {
  static NSCharacterSet *allowedCharacters;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableCharacterSet *set = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [set removeCharactersInString:@"?&=@+/'"];
    allowedCharacters = set;
  });
  
  NSMutableArray<NSString *> *parts = [NSMutableArray array];
  for (NSString *key in keyValues) {
    [parts addObject:[NSString stringWithFormat:@"%@=%@",
                      [key stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters],
                      [keyValues[key] stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters]]];
  }
  return [[parts componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
}

static NSString *GetSessionCookie(NSURLSession *session) {
  for (NSHTTPCookie *cookie in session.configuration.HTTPCookieStorage.cookies) {
    if ([cookie.name isEqualToString:@(kWanikaniSessionCookieName)]) {
      return cookie.value;
    }
  }
  return nil;
}

@implementation Client {
  NSString *_apiToken;
  NSString *_cookie;
  NSURLSession *_urlSession;
  NSDateFormatter *_dateFormatter;
  NSString *_csrfToken;
  NSDate *_csrfTokenUpdated;
}

- (instancetype)initWithApiToken:(NSString *)apiToken
                          cookie:(NSString *)cookie {
  EnsureInitialised();
  
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

+ (NSMutableURLRequest *)authorizeUserRequest:(NSURL *)url
                                   withCookie:(NSString *)cookie {
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"%s=%@", kWanikaniSessionCookieName, cookie]
      forHTTPHeaderField:@"Cookie"];
  return req;
}

- (NSMutableURLRequest *)authorizeUserRequest:(NSURL *)url {
  return [Client authorizeUserRequest:url withCookie:_cookie];
}

#pragma mark - Query utilities

- (NSString *)currentISO8601Time {
  return [_dateFormatter stringFromDate:[NSDate date]];
}

- (void)startPagedQueryFor:(NSURL *)url
                   handler:(PartialResponseHandler)handler {
  if (self.pretendToBeOfflineForTesting) {
    handler(nil, MakeError(42, @"I'm offline"));
    return;
  }
  
  NSURLRequest *req = [self authorizeAPIRequest:url];
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

- (void)putWithCSRFToken:(NSURL *)url
             contentType:(NSString *)contentType
                    data:(NSData *)data
                 handler:(PUTResponseHandler)handler {
  if (self.pretendToBeOfflineForTesting) {
    handler(MakeError(42, @"I'm offline"));
    return;
  }
  
  NSMutableURLRequest *req = [self authorizeUserRequest:url];
  [req addValue:_csrfToken forHTTPHeaderField:@"X-CSRF-Token"];
  [req addValue:contentType forHTTPHeaderField:@"Content-Type"];
  [req addValue:[@(data.length) stringValue] forHTTPHeaderField:@"Content-Length"];
  req.HTTPMethod = @"PUT";
  req.HTTPBody = data;
  
  // Start the request.
  NSLog(@"PUT %@ to %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], req.URL);
  NSURLSessionDataTask *task =
      [_urlSession dataTaskWithRequest:req
                     completionHandler:^(NSData * _Nullable data,
                                         NSURLResponse * _Nullable response,
                                         NSError * _Nullable error) {
                       if (handler) {
                         handler(error);
                       }
                     }];
  [task resume];
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
  if (!dict[@"pages"][@"next_url"]) {
    // This is a single-page query, so don't call the handler again.
    return;
  }
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

#pragma mark - API token

+ (void)getCookieForUsername:(NSString *)username
                    password:(NSString *)password
                     handler:(CookieHandler)handler {
  EnsureInitialised();
  
  NSURL *url = [NSURL URLWithString:@(kLoginURL)];
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

  __block NSString *csrfToken = nil;
  __block NSString *originalCookie = nil;
  void (^secondHandler)(NSData * _Nullable data,
                        NSURLResponse * _Nullable response,
                        NSError * _Nullable error) = ^void(NSData * _Nullable data,
                                                           NSURLResponse * _Nullable response,
                                                           NSError * _Nullable error) {
    if (error != nil) {
      handler(error, nil);
      return;
    }
    
    NSString *newCookie = GetSessionCookie(session);
    if ([newCookie isEqualToString:originalCookie]) {
      handler(MakeError(kTKMLoginErrorCode, @"Bad credentials"), nil);
      return;
    } else if ([response.URL.absoluteString isEqualToString:@(kDashboardURL)]) {
      handler(nil, newCookie);
      return;
    }
    
    handler(MakeError(0, @"Unknown error"), nil);
  };
  
  void (^firstHandler)(NSData * _Nullable data,
                       NSURLResponse * _Nullable response,
                       NSError * _Nullable error) = ^void(NSData * _Nullable data,
                                                          NSURLResponse * _Nullable response,
                                                          NSError * _Nullable error) {
    if (error != nil) {
      handler(error, nil);
      return;
    }
    csrfToken = ParseCSRFTokenFromResponse(data, response, &error);
    if (error != nil) {
      handler(error, nil);
      return;
    }
    
    originalCookie = GetSessionCookie(session);
    
    NSMutableDictionary<NSString *, NSString *> *postData = [NSMutableDictionary dictionary];
    postData[@"user[login]"] = username;
    postData[@"user[password]"] = password;
    postData[@"user[remember_me]"] = @"0";
    postData[@"authenticity_token"] = csrfToken;
    postData[@"utf8"] = @"✓";
    NSData *postDataBytes = EncodeQueryString(postData);
    
    NSMutableURLRequest *post = [NSMutableURLRequest requestWithURL:url];
    post.HTTPBody = postDataBytes;
    post.HTTPShouldHandleCookies = YES;
    post.HTTPMethod = @"POST";
    [post addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [post addValue:[@(postDataBytes.length) stringValue] forHTTPHeaderField:@"Content-Length"];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:post
                                            completionHandler:secondHandler];
    [task resume];
  };
  
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  req.HTTPShouldHandleCookies = YES;
  NSURLSessionDataTask *task = [session dataTaskWithRequest:req
                                          completionHandler:firstHandler];
  [task resume];
}

+ (void)getApiTokenForCookie:(NSString *)cookie handler:(ApiTokenHandler)handler {
  EnsureInitialised();
  
  NSURLRequest *req = [Client authorizeUserRequest:[NSURL URLWithString:@(kAccountURL)]
                                        withCookie:cookie];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task =
      [session dataTaskWithRequest:req
                 completionHandler:^(NSData * _Nullable data,
                                     NSURLResponse * _Nullable response,
                                     NSError * _Nullable error) {
                   if (error != nil) {
                     handler(error, nil, nil);
                     return;
                   }
                   NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                   if (httpResponse.statusCode != 200) {
                     handler(MakeError((int)httpResponse.statusCode,
                                       [NSString stringWithFormat:@"HTTP error %ld for %@",
                                        (long)httpResponse.statusCode,
                                        response.URL.absoluteString]), nil, nil);
                     return;
                   }
                   
                   NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                   NSTextCheckingResult *apiTokenResult =
                      [sAPITokenRE firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
                   if (!apiTokenResult || apiTokenResult.range.location == NSNotFound) {
                     handler(MakeError(0, @"API token not found in page"), nil, nil);
                     return;
                   }

                   NSTextCheckingResult *emailAddressResult =
                      [sEmailAddressRE firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
                   if (!emailAddressResult || emailAddressResult.range.location == NSNotFound) {
                     handler(MakeError(0, @"Email address not found in page"), nil, nil);
                     return;
                   }
                   
                   NSString *token = [body substringWithRange:[apiTokenResult rangeAtIndex:1]];
                   NSString *emailAddress = [body substringWithRange:[emailAddressResult rangeAtIndex:1]];
                   handler(nil, token, emailAddress);
                 }];
  [task resume];
}

#pragma mark - Assignments

- (void)getAssignmentsModifiedAfter:(NSString *)date
                            handler:(AssignmentHandler)handler {
  NSMutableArray<TKMAssignment *> *ret = [NSMutableArray array];

  NSURLComponents *url =
      [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%s/assignments",
                                             kURLBase]];
  NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"unlocked" value:@"true"]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"hidden" value:@"false"]];
  if (date && date.length) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"updated_after" value:date]];
  }
  [url setQueryItems:queryItems];
  
  [self startPagedQueryFor:url.URL handler:^(NSArray *data, NSError *error) {
    if (error) {
      handler(error, nil);
      return;
    } else if (!data) {
      handler(nil, ret);
      return;
    }
    
    for (NSDictionary *d in data) {
      TKMAssignment *assignment = [[TKMAssignment alloc] init];
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
      
      if (d[@"data"][@"passed_at"] != [NSNull null]) {
        assignment.passedAt =
            [[_dateFormatter dateFromString:d[@"data"][@"passed_at"]] timeIntervalSince1970];
      }
      
      NSString *subjectType = d[@"data"][@"subject_type"];
      if ([subjectType isEqualToString:@"radical"]) {
        assignment.subjectType = TKMSubject_Type_Radical;
      } else if ([subjectType isEqualToString:@"kanji"]) {
        assignment.subjectType = TKMSubject_Type_Kanji;
      } else if ([subjectType isEqualToString:@"vocabulary"]) {
        assignment.subjectType = TKMSubject_Type_Vocabulary;
      } else {
        NSAssert(false, @"Unknown subject type %@", subjectType);
      }
      [ret addObject:assignment];
    }
  }];
}

#pragma mark - Progress

- (void)fetchCSRFToken:(ProgressHandler)handler {
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
    _csrfToken = ParseCSRFTokenFromResponse(data, response, &error);
    if (!error) {
      _csrfTokenUpdated = [NSDate date];
    }
    handler(error);
  }];
  [task resume];
}

- (bool)isCSRFTokenValid {
  return _csrfToken.length &&
      - [_csrfTokenUpdated timeIntervalSinceNow] < kCSRFTokenValidity;
}

- (void)ensureValidCSRFTokenAndThen:(void (^)(NSError * _Nullable))handler {
  // Fetch a new CSRF token if it's invalid or expired.
  if ([self isCSRFTokenValid]) {
    handler(nil);
  } else {
    [self fetchCSRFToken:handler];
  }
}

- (void)sendProgress:(NSArray<TKMProgress *> *)progress
             handler:(ProgressHandler _Nullable)handler {
  if (progress.count == 0) {
    handler(nil);
    return;
  }

  // Split the progress array into reviews and lessons.
  NSMutableArray<TKMProgress *> *reviewProgress = [NSMutableArray array];
  NSMutableArray<TKMProgress *> *lessonProgress = [NSMutableArray array];
  for (TKMProgress *p in progress) {
    if (p.isLesson) {
      [lessonProgress addObject:p];
    } else {
      [reviewProgress addObject:p];
    }
  }
  
  [self ensureValidCSRFTokenAndThen:^(NSError * _Nullable error) {
    if (error != nil) {
      handler(error);
      return;
    }
    
    __block NSError *lastError = nil;

    dispatch_group_t dispatchGroup = dispatch_group_create();
    if (reviewProgress.count) {
      dispatch_group_enter(dispatchGroup);
      [self sendReviewProgress:reviewProgress
                       handler:^(NSError *_Nullable error) {
                         if (error != nil) {
                           lastError = error;
                           NSLog(@"Failed to send review progress: %@", error);
                         }
                         dispatch_group_leave(dispatchGroup);
                       }];
    }
    if (lessonProgress.count) {
      dispatch_group_enter(dispatchGroup);
      [self sendLessonProgress:lessonProgress
                       handler:^(NSError *_Nullable error) {
                         if (error != nil) {
                           lastError = error;
                           NSLog(@"Failed to send lesson progress: %@", error);
                         }
                         dispatch_group_leave(dispatchGroup);
                       }];
    }

    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_group_notify(dispatchGroup, queue, ^{
      handler(lastError);
    });
  }];
}

- (void)sendReviewProgress:(NSArray<TKMProgress *> *)progress
                   handler:(ProgressHandler)handler {
  // Encode the data to send in the request.
  NSMutableArray<NSString *> *formParameters = [NSMutableArray array];
  for (TKMProgress *p in progress) {
    [formParameters addObject:p.reviewFormParameters];
  }
  NSData *data = [[formParameters componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
  
  [self putWithCSRFToken:[NSURL URLWithString:@(kReviewProgressURL)]
             contentType:kFormDataContentType
                    data:data
                 handler:handler];
}

- (void)sendLessonProgress:(NSArray<TKMProgress *> *)progress
                   handler:(ProgressHandler _Nullable)handler {
  // Encode the data to send in the request.
  NSMutableArray<NSString *> *formParameters = [NSMutableArray array];
  for (TKMProgress *p in progress) {
    [formParameters addObject:p.lessonFormParameters];
  }
  NSData *data = [[formParameters componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
  
  [self putWithCSRFToken:[NSURL URLWithString:@(kLessonProgressURL)]
             contentType:kFormDataContentType
                    data:data
                 handler:handler];
}

#pragma mark - Study Materials

- (void)getStudyMaterialsModifiedAfter:(NSString *)date
                               handler:(StudyMaterialsHandler)handler {
  NSMutableArray<TKMStudyMaterials *> *ret = [NSMutableArray array];

  NSURLComponents *url =
      [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%s/study_materials",
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
      TKMStudyMaterials *studyMaterials = [[TKMStudyMaterials alloc] init];
      studyMaterials.id_p = [d[@"id"] intValue];
      studyMaterials.subjectId = [d[@"data"][@"subject_id"] intValue];
      studyMaterials.subjectType = d[@"data"][@"subject_type"];

      if (d[@"data"][@"meaning_note"] != [NSNull null]) {
        studyMaterials.meaningNote = d[@"data"][@"meaning_note"];
      }
      if (d[@"data"][@"reading_note"] != [NSNull null]) {
        studyMaterials.meaningNote = d[@"data"][@"reading_note"];
      }
      if (d[@"data"][@"meaning_synonyms"] != [NSNull null]) {
        studyMaterials.meaningSynonymsArray = d[@"data"][@"meaning_synonyms"];
      }
      [ret addObject:studyMaterials];
    }
  }];
}

- (void)updateStudyMaterial:(TKMStudyMaterials *)material
                    handler:(UpdateStudyMaterialHandler)handler {
  [self ensureValidCSRFTokenAndThen:^(NSError * _Nullable error) {
    if (error != nil) {
      handler(error);
      return;
    }
    
    // Encode the data to send in the request.
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:@(material.subjectId) forKey:@"subject_id"];
    [payload setObject:material.subjectType forKey:@"subject_type"];
    [payload setObject:material.meaningSynonymsArray forKey:@"meaning_synonyms"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    NSString *urlString = [NSString stringWithFormat:@"%s/%d",
                           kStudyMaterialsURLBase, material.subjectId];
    [self putWithCSRFToken:[NSURL URLWithString:urlString]
               contentType:kJSONContentType
                      data:data
                   handler:handler];
  }];
}

#pragma mark - User Info

- (void)getUserInfo:(UserInfoHandler)handler {
  NSURLComponents *url =
  [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%s/user", kURLBase]];
  
  [self startPagedQueryFor:url.URL handler:^(NSDictionary *data, NSError *error) {
    if (error) {
      handler(error, nil);
      return;
    }
    
    TKMUser *ret = [[TKMUser alloc] init];
    ret.username = data[@"username"];
    ret.level = [data[@"level"] intValue];
    ret.maxLevelGrantedBySubscription = [data[@"max_level_granted_by_subscription"] intValue];
    ret.profileURL = data[@"profile_url"];
    ret.subscribed = [data[@"subscribed"] boolValue];
    
    if (data[@"started_at"] != [NSNull null]) {
      ret.startedAt = [[_dateFormatter dateFromString:data[@"started_at"]] timeIntervalSince1970];
    }
    
    handler(nil, ret);
  }];
}

@end

NS_ASSUME_NONNULL_END
