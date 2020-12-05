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
#import "Extensions/ProtobufExtensions.h"

#import "Tsurukame-Swift.h"

NS_ASSUME_NONNULL_BEGIN

const char *kWanikaniSessionCookieName = "_wanikani_session";
static const char *kURLBase = "https://api.wanikani.com/v2";
static const char *kAccountURL = "https://www.wanikani.com/settings/account";
static const char *kAccessTokenURL = "https://www.wanikani.com/settings/personal_access_tokens";
static const char *kNewAccessTokenURL =
    "https://www.wanikani.com/settings/personal_access_tokens/new";
static const char *kLoginURL = "https://www.wanikani.com/login";
static const char *kDashboardURL = "https://www.wanikani.com/dashboard";

static const char *kCSRFTokenREPattern = "<meta name=\"csrf-token\" content=\"([^\"]*)";
static const char *kEmailAddressREPattern = "<input[^>]+value=\"([^\"]+)\"[^>]+id=\"user_email\"";
static const char *kAPITokenREPattern =
    "personal-access-token-description\">\\s*"
    "Tsurukame\\s*"
    "</td>\\s*"
    "<td class=\"personal-access-token-token\">\\s*"
    "<code>([a-f0-9-]{36})</code>";
static const char *kAuthenticityTokenREPattern = "name=\"authenticity_token\" value=\"([^\"]+)\"";

NSErrorDomain const kTKMClientErrorDomain = @"kTKMClientErrorDomain";
static NSErrorUserInfoKey const kTKMClientErrorRequestKey = @"kTKMClientErrorRequestKey";
static NSErrorUserInfoKey const kTKMClientErrorResponseKey = @"kTKMClientErrorResponseKey";
static NSErrorUserInfoKey const kTKMClientErrorResponseDataKey = @"kTKMClientErrorResponseDataKey";

const int kTKMLoginErrorCode = 403;

bool TKMIsClientError(NSError *error) { return [error.domain isEqual:kTKMClientErrorDomain]; }

@implementation TKMClientError

- (nullable NSURLRequest *)request {
  return (NSURLRequest *)self.userInfo[kTKMClientErrorRequestKey];
}

- (nullable NSHTTPURLResponse *)response {
  return (NSHTTPURLResponse *)self.userInfo[kTKMClientErrorResponseKey];
}

- (nullable NSData *)responseData {
  return (NSData *)self.userInfo[kTKMClientErrorResponseDataKey];
}

+ (instancetype)httpErrorWithRequest:(NSURLRequest *)request
                            response:(NSURLResponse *)response
                        responseData:(NSData *)responseData {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  NSString *msg =
      [NSString stringWithFormat:@"HTTP error %ld for %@", (long)httpResponse.statusCode,
                                 response.URL.absoluteString];
  return [self httpErrorWithMessage:msg
                            request:request
                           response:response
                       responseData:responseData];
}

+ (instancetype)httpErrorWithMessage:(NSString *)message
                             request:(nullable NSURLRequest *)request
                            response:(NSURLResponse *)response
                        responseData:(NSData *)responseData {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSLocalizedDescriptionKey] = message;
  userInfo[kTKMClientErrorResponseKey] = response;
  userInfo[kTKMClientErrorResponseDataKey] = responseData;
  userInfo[kTKMClientErrorRequestKey] = request;

  return [self errorWithDomain:kTKMClientErrorDomain
                          code:httpResponse.statusCode
                      userInfo:userInfo];
}

+ (instancetype)errorWithMessage:(NSString *)message {
  return [self errorWithMessage:message code:0];
}

+ (instancetype)errorWithMessage:(NSString *)message code:(int)code {
  return [self errorWithDomain:kTKMClientErrorDomain
                          code:code
                      userInfo:@{NSLocalizedDescriptionKey : message}];
}

@end

static NSRegularExpression *sCSRFTokenRE;
static NSRegularExpression *sEmailAddressRE;
static NSRegularExpression *sAPITokenRE;
static NSRegularExpression *sAuthenticityTokenRE;
static NSArray<NSDateFormatter *> *sDateFormatters;

typedef void (^PartialResponseHandler)(NSString *_Nullable dataUpdatedAt,
                                       id _Nullable data,
                                       int page,
                                       int totalPages,
                                       NSError *_Nullable error);

static void EnsureInitialised() {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sCSRFTokenRE = [NSRegularExpression regularExpressionWithPattern:@(kCSRFTokenREPattern)
                                                             options:0
                                                               error:nil];
    sEmailAddressRE = [NSRegularExpression regularExpressionWithPattern:@(kEmailAddressREPattern)
                                                                options:0
                                                                  error:nil];
    sAPITokenRE = [NSRegularExpression regularExpressionWithPattern:@(kAPITokenREPattern)
                                                            options:0
                                                              error:nil];
    sAuthenticityTokenRE =
        [NSRegularExpression regularExpressionWithPattern:@(kAuthenticityTokenREPattern)
                                                  options:0
                                                    error:nil];

    NSDateFormatter * (^makeDateFormatter)(NSString *format) = ^(NSString *format) {
      NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
      formatter.dateFormat = format;
      formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
      formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
      return formatter;
    };

    sDateFormatters = @[
      makeDateFormatter(@"yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"),
      makeDateFormatter(@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"),
      makeDateFormatter(@"yyyy-MM-dd'T'HH:mm:ss'Z'"),
      makeDateFormatter(@"yyyyMMdd'T'HH:mm:ss.SSSSSS'Z'"),
      makeDateFormatter(@"yyyyMMdd'T'HH:mm:ss.SSS'Z'"),
      makeDateFormatter(@"yyyyMMdd'T'HH:mm:ss'Z'"),
      makeDateFormatter(@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSX"),
      makeDateFormatter(@"yyyy-MM-dd'T'HH:mm:ss.SSSX"),
      makeDateFormatter(@"yyyy-MM-dd'T'HH:mm:ssX"),
    ];
  });
}

static NSString *ParseCSRFTokenFromResponse(NSData *data,
                                            NSURLRequest *request,
                                            NSURLResponse *response,
                                            NSError **error) {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  if (httpResponse.statusCode != 200) {
    *error = [TKMClientError httpErrorWithRequest:request response:response responseData:data];
    return nil;
  }

  NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSTextCheckingResult *result = [sCSRFTokenRE firstMatchInString:body
                                                          options:0
                                                            range:NSMakeRange(0, body.length)];
  if (!result || result.range.location == NSNotFound) {
    *error = [TKMClientError httpErrorWithMessage:@"Progress token not found on page"
                                          request:request
                                         response:response
                                     responseData:data];
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
    [parts addObject:
               [NSString
                   stringWithFormat:
                       @"%@=%@",
                       [key stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters],
                       [keyValues[key]
                           stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters]]];
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
  DataLoader *_dataLoader;
  NSURLSession *_urlSession;
}

- (instancetype)initWithApiToken:(NSString *)apiToken
                          cookie:(NSString *)cookie
                      dataLoader:(DataLoader *)dataLoader {
  EnsureInitialised();

  if (self = [super init]) {
    _apiToken = apiToken;
    _cookie = cookie;
    _dataLoader = dataLoader;

    NSURLSessionConfiguration *sessionConfiguration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    _urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration];
  }
  return self;
}

- (void)updateApiToken:(NSString *)apiToken cookie:(NSString *)cookie {
  _apiToken = apiToken;
  _cookie = cookie;
}

#pragma mark - Date functions

+ (NSString *)formatISO8601Date:(NSDate *)date {
  EnsureInitialised();
  return [sDateFormatters.firstObject stringFromDate:date];
}

+ (NSString *)currentISO8601Date {
  return [self formatISO8601Date:[NSDate date]];
}

+ (NSDate *)parseISO8601Date:(NSString *)string {
  EnsureInitialised();
  for (NSDateFormatter *formatter in sDateFormatters) {
    NSDate *date = [formatter dateFromString:string];
    if (date) {
      return date;
    }
  }
  return nil;
}

#pragma mark - Authorization

- (NSMutableURLRequest *)authorizeAPIRequest:(NSURL *)url {
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"Token token=%@", _apiToken]
      forHTTPHeaderField:@"Authorization"];
  return req;
}

+ (NSMutableURLRequest *)authorizeUserRequest:(NSURL *)url withCookie:(NSString *)cookie {
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"%s=%@", kWanikaniSessionCookieName, cookie]
      forHTTPHeaderField:@"Cookie"];
  return req;
}

- (NSMutableURLRequest *)authorizeUserRequest:(NSURL *)url {
  return [Client authorizeUserRequest:url withCookie:_cookie];
}

#pragma mark - Query utilities

- (void)startPagedQueryFor:(NSURL *)url handler:(PartialResponseHandler)handler {
  if (self.pretendToBeOfflineForTesting) {
    handler(nil, nil, 0, 0, [TKMClientError errorWithMessage:@"Offline for testing" code:42]);
    return;
  }

  NSURLRequest *req = [self authorizeAPIRequest:url];
  NSURLSessionDataTask *task =
      [_urlSession dataTaskWithRequest:req
                     completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                         NSError *_Nullable error) {
                       [self parseJsonResponse:data
                                       request:req
                                      response:response
                                         error:error
                                       handler:handler
                                          page:1];
                     }];
  [task resume];
}

- (void)submitJSONToURL:(NSURL *)url
             withMethod:(NSString *)method
                   data:(NSData *)data
                handler:(PartialResponseHandler)handler {
  if (self.pretendToBeOfflineForTesting) {
    handler(nil, nil, 0, 0, [TKMClientError errorWithMessage:@"Offline for testing" code:42]);
    return;
  }

  NSMutableURLRequest *req = [self authorizeAPIRequest:url];
  [req addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [req addValue:[@(data.length) stringValue] forHTTPHeaderField:@"Content-Length"];
  req.HTTPMethod = method;
  req.HTTPBody = data;

  // Start the request.
  NSLog(@"%@ %@ to %@",
        method,
        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
        req.URL);
  NSURLSessionDataTask *task =
      [_urlSession dataTaskWithRequest:req
                     completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                         NSError *_Nullable error) {
                       [self parseJsonResponse:data
                                       request:req
                                      response:response
                                         error:error
                                       handler:handler
                                          page:1];
                     }];
  [task resume];
}

- (void)parseJsonResponse:(NSData *)data
                  request:(NSURLRequest *)request
                 response:(NSURLResponse *)response
                    error:(NSError *)error
                  handler:(PartialResponseHandler)handler
                     page:(int)page {
  if (error != nil) {
    handler(nil, nil, 0, 0, error);
    return;
  }
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (error != nil) {
    handler(nil, nil, 0, 0, error);
    return;
  }
  if (dict[@"error"] != nil) {
    handler(nil, nil, 0, false,
            [TKMClientError httpErrorWithMessage:dict[@"error"]
                                         request:request
                                        response:response
                                    responseData:data]);
    return;
  }

  bool hasMore = dict[@"pages"][@"next_url"] != nil && dict[@"pages"][@"next_url"] != [NSNull null];
  int totalCount = [dict[@"total_count"] intValue];
  int perPage = [dict[@"pages"][@"per_page"] intValue];
  int totalPages = 1;
  if (totalCount > 0) {
    totalPages = ceil((double)totalCount / perPage);
  }

  handler(dict[@"data_updated_at"], dict[@"data"], page, totalPages, nil);

  // Get the next page if we have one.
  if (hasMore) {
    NSString *nextURLString = dict[@"pages"][@"next_url"];
    NSLog(@"Request: %@", nextURLString);
    NSURLRequest *req = [self authorizeAPIRequest:[NSURL URLWithString:nextURLString]];
    NSURLSessionDataTask *task = [_urlSession
        dataTaskWithRequest:req
          completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                              NSError *_Nullable error) {
            [self parseJsonResponse:data
                            request:req
                           response:response
                              error:error
                            handler:handler
                               page:page + 1];
          }];
    [task resume];
  }
}

#pragma mark - API token

+ (void)getCookieForUsername:(NSString *)username
                    password:(NSString *)password
                     handler:(CookieHandler)handler {
  EnsureInitialised();

  NSURL *url = [NSURL URLWithString:@(kLoginURL)];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration ephemeralSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];

  NSMutableURLRequest *firstRequest = [NSMutableURLRequest requestWithURL:url];
  NSMutableURLRequest *secondRequest = [NSMutableURLRequest requestWithURL:url];

  __block NSString *csrfToken = nil;
  __block NSString *originalCookie = nil;
  void (^secondHandler)(NSData *_Nullable data, NSURLResponse *_Nullable response,
                        NSError *_Nullable error) =
      ^void(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error != nil) {
          handler(error, nil);
          return;
        }

        NSString *newCookie = GetSessionCookie(session);
        if ([newCookie isEqualToString:originalCookie]) {
          handler([TKMClientError errorWithMessage:@"Bad credentials" code:kTKMLoginErrorCode],
                  nil);
          return;
        } else if ([response.URL.absoluteString isEqualToString:@(kDashboardURL)]) {
          handler(nil, newCookie);
          return;
        }

        handler([TKMClientError errorWithMessage:@"Unknown error"], nil);
      };

  void (^firstHandler)(NSData *_Nullable data, NSURLResponse *_Nullable response,
                       NSError *_Nullable error) =
      ^void(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error != nil) {
          handler(error, nil);
          return;
        }
        csrfToken = ParseCSRFTokenFromResponse(data, firstRequest, response, &error);
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

        secondRequest.HTTPBody = postDataBytes;
        secondRequest.HTTPShouldHandleCookies = YES;
        secondRequest.HTTPMethod = @"POST";
        [secondRequest addValue:@"application/x-www-form-urlencoded"
             forHTTPHeaderField:@"Content-Type"];
        [secondRequest addValue:[@(postDataBytes.length) stringValue]
             forHTTPHeaderField:@"Content-Length"];

        NSURLSessionDataTask *task = [session dataTaskWithRequest:secondRequest
                                                completionHandler:secondHandler];
        [task resume];
      };

  firstRequest.HTTPShouldHandleCookies = YES;
  NSURLSessionDataTask *task = [session dataTaskWithRequest:firstRequest
                                          completionHandler:firstHandler];
  [task resume];
}

+ (void)getApiTokenForCookie:(NSString *)cookie handler:(ApiTokenHandler)handler {
  EnsureInitialised();
  [self getApiTokenForCookie:cookie handler:handler createIfNotFound:YES];
}

+ (void)getApiTokenForCookie:(NSString *)cookie
                     handler:(ApiTokenHandler)handler
            createIfNotFound:(BOOL)createIfNotFound {
  NSLog(@"Getting API token...");
  NSURLRequest *req = [Client authorizeUserRequest:[NSURL URLWithString:@(kAccessTokenURL)]
                                        withCookie:cookie];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task =
      [session dataTaskWithRequest:req
                 completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   [self handleGetApiTokenData:data
                                       request:req
                                      response:response
                                         error:error
                                     forCookie:cookie
                                       handler:handler
                              createIfNotFound:createIfNotFound];
                 }];
  [task resume];
}

+ (void)handleGetApiTokenData:(nullable NSData *)data
                      request:(NSURLRequest *)req
                     response:(nullable NSURLResponse *)response
                        error:(nullable NSError *)error
                    forCookie:(NSString *)cookie
                      handler:(ApiTokenHandler)handler
             createIfNotFound:(BOOL)createIfNotFound {
  if (error != nil) {
    handler(error, nil, nil);
    return;
  }
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  if (httpResponse.statusCode != 200) {
    handler([TKMClientError httpErrorWithRequest:req response:response responseData:data], nil,
            nil);
    return;
  }

  NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

  NSTextCheckingResult *result = [sAPITokenRE firstMatchInString:body
                                                         options:0
                                                           range:NSMakeRange(0, body.length)];
  if (!result || result.range.location == NSNotFound) {
    if (createIfNotFound) {
      NSLog(@"API token not found - creating a new one");
      [self createApiTokenForCookie:cookie handler:handler];
    } else {
      handler([TKMClientError httpErrorWithMessage:@"API token not found in page"
                                           request:req
                                          response:response
                                      responseData:data],
              nil,
              nil);
    }
    return;
  }

  NSString *token = [body substringWithRange:[result rangeAtIndex:1]];
  NSLog(@"API token found: %@", token);
  [self getEmailForCookie:cookie accessToken:token handler:handler];
}

+ (void)getEmailForCookie:(NSString *)cookie
              accessToken:(NSString *)token
                  handler:(ApiTokenHandler)handler {
  NSURLRequest *req = [Client authorizeUserRequest:[NSURL URLWithString:@(kAccountURL)]
                                        withCookie:cookie];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task = [session
      dataTaskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                            NSError *_Nullable error) {
          if (error != nil) {
            handler(error, nil, nil);
            return;
          }
          NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
          if (httpResponse.statusCode != 200) {
            handler([TKMClientError httpErrorWithRequest:req response:response responseData:data],
                    nil,
                    nil);
            return;
          }

          NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

          NSTextCheckingResult *result =
              [sEmailAddressRE firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
          if (!result || result.range.location == NSNotFound) {
            handler([TKMClientError httpErrorWithMessage:@"Email address not found in page"
                                                 request:req
                                                response:response
                                            responseData:data],
                    nil,
                    nil);
            return;
          }

          NSString *emailAddress = [body substringWithRange:[result rangeAtIndex:1]];
          NSLog(@"Email found: %@", emailAddress);
          handler(nil, token, emailAddress);
        }];
  [task resume];
}

+ (void)createApiTokenForCookie:(NSString *)cookie handler:(ApiTokenHandler)handler {
  NSURLRequest *req = [Client authorizeUserRequest:[NSURL URLWithString:@(kNewAccessTokenURL)]
                                        withCookie:cookie];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task = [session
      dataTaskWithRequest:req
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                            NSError *_Nullable error) {
          if (error != nil) {
            handler(error, nil, nil);
            return;
          }
          NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
          if (httpResponse.statusCode != 200) {
            handler([TKMClientError httpErrorWithRequest:req response:response responseData:data],
                    nil,
                    nil);
            return;
          }

          NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

          NSTextCheckingResult *result =
              [sAuthenticityTokenRE firstMatchInString:body
                                               options:0
                                                 range:NSMakeRange(0, body.length)];
          if (!result || result.range.location == NSNotFound) {
            handler([TKMClientError httpErrorWithMessage:@"Authenticity token not found in page"
                                                 request:req
                                                response:response
                                            responseData:data],
                    nil,
                    nil);
            return;
          }

          NSString *authenticityToken = [body substringWithRange:[result rangeAtIndex:1]];
          NSLog(@"authenticityToken found: %@", authenticityToken);
          [self createApiTokenForCookie:cookie authenticityToken:authenticityToken handler:handler];
        }];
  [task resume];
}

+ (void)createApiTokenForCookie:(NSString *)cookie
              authenticityToken:(NSString *)authenticityToken
                        handler:(ApiTokenHandler)handler {
  NSMutableURLRequest *req = [Client authorizeUserRequest:[NSURL URLWithString:@(kAccessTokenURL)]
                                               withCookie:cookie];
  NSMutableDictionary<NSString *, NSString *> *postData = [NSMutableDictionary dictionary];
  postData[@"authenticity_token"] = authenticityToken;
  postData[@"personal_access_token[description]"] = @"Tsurukame";
  postData[@"personal_access_token[permissions][assignments][start]"] = @"1";
  postData[@"personal_access_token[permissions][reviews][create]"] = @"1";
  postData[@"personal_access_token[permissions][reviews][update]"] = @"1";
  postData[@"personal_access_token[permissions][study_materials][create]"] = @"1";
  postData[@"personal_access_token[permissions][study_materials][update]"] = @"1";
  postData[@"utf8"] = @"✓";
  NSData *postDataBytes = EncodeQueryString(postData);

  req.HTTPBody = postDataBytes;
  req.HTTPMethod = @"POST";
  [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
  [req addValue:[@(postDataBytes.length) stringValue] forHTTPHeaderField:@"Content-Length"];

  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task =
      [session dataTaskWithRequest:req
                 completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   [self handleGetApiTokenData:data
                                       request:req
                                      response:response
                                         error:error
                                     forCookie:cookie
                                       handler:handler
                              createIfNotFound:NO];
                 }];
  [task resume];
}

#pragma mark - Assignments

- (void)getAssignmentsModifiedAfter:(NSString *_Nullable)date
                    progressHandler:(PartialCompletionHandler)progressHandler
                            handler:(AssignmentHandler)handler {
  NSMutableArray<TKMAssignment *> *ret = [NSMutableArray array];

  NSURLComponents *url = [NSURLComponents
      componentsWithString:[NSString stringWithFormat:@"%s/assignments", kURLBase]];
  NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"unlocked" value:@"true"]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"hidden" value:@"false"]];
  if (date && date.length) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"updated_after" value:date]];
  }
  [url setQueryItems:queryItems];

  [self startPagedQueryFor:url.URL
                   handler:^(NSString *dataUpdatedAt, NSArray *data, int page, int totalPages,
                             NSError *error) {
                     if (error) {
                       progressHandler(1, 1);
                       handler(error, nil, nil);
                       return;
                     }

                     for (NSDictionary *d in data) {
                       TKMAssignment *assignment = [TKMAssignment message];
                       assignment.id_p = [d[@"id"] intValue];
                       assignment.subjectId = [d[@"data"][@"subject_id"] intValue];
                       assignment.srsStage = [d[@"data"][@"srs_stage"] intValue];
                       assignment.level = (int)[_dataLoader levelOfSubjectID:assignment.subjectId];

                       if (d[@"data"][@"available_at"] != [NSNull null]) {
                         assignment.availableAt = [[Client
                             parseISO8601Date:d[@"data"][@"available_at"]] timeIntervalSince1970];
                       }

                       if (d[@"data"][@"started_at"] != [NSNull null]) {
                         assignment.startedAt = [[Client parseISO8601Date:d[@"data"][@"started_at"]]
                             timeIntervalSince1970];
                       }

                       if (d[@"data"][@"passed_at"] != [NSNull null]) {
                         assignment.passedAt = [[Client parseISO8601Date:d[@"data"][@"passed_at"]]
                             timeIntervalSince1970];
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

                     progressHandler(page, totalPages);
                     if (page == totalPages) {
                       handler(nil, dataUpdatedAt, ret);
                     }
                   }];
}

#pragma mark - Progress

- (void)sendProgress:(TKMProgress *)progress handler:(ProgressHandler)handler {
  if (progress.isLesson) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    if (progress.hasCreatedAt) {
      [payload setObject:[Client formatISO8601Date:progress.createdAtDate] forKey:@"started_at"];
    }

    NSString *urlString =
        [NSString stringWithFormat:@"%s/assignments/%d/start", kURLBase, progress.assignment.id_p];
    [self submitJSONToURL:[NSURL URLWithString:urlString]
               withMethod:@"PUT"
                     data:[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil]
                  handler:^(NSString *dataUpdatedAt, id _Nullable data, int page, int totalPages,
                            NSError *_Nullable error) {
                    handler(error);
                  }];
    return;
  }

  // Encode the data to send in the request.
  NSMutableDictionary *review = [NSMutableDictionary dictionary];
  [review setObject:@(progress.assignment.id_p) forKey:@"assignment_id"];
  if (Settings.minimizeReviewPenalty) {
    [review setObject:@(progress.meaningWrong ? 1 : 0) forKey:@"incorrect_meaning_answers"];
    [review setObject:@(progress.readingWrong ? 1 : 0) forKey:@"incorrect_reading_answers"];
  } else {
    [review setObject:@(progress.meaningWrongCount) forKey:@"incorrect_meaning_answers"];
    [review setObject:@(progress.readingWrongCount) forKey:@"incorrect_reading_answers"];
  }
  if (progress.hasCreatedAt) {
    NSTimeInterval interval = [progress.createdAtDate timeIntervalSinceNow];
    // Don't set created_at if it's very recent to try and allow for some
    // clock drift.
    if (interval < -900) {
      [review setObject:[Client formatISO8601Date:progress.createdAtDate] forKey:@"created_at"];
    }
  }

  NSMutableDictionary *payload = [NSMutableDictionary dictionary];
  [payload setObject:review forKey:@"review"];
  NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

  NSString *urlString = [NSString stringWithFormat:@"%s/reviews/", kURLBase];
  [self submitJSONToURL:[NSURL URLWithString:urlString]
             withMethod:@"POST"
                   data:data
                handler:^(NSString *dataUpdatedAt, id _Nullable data, int page, int totalPages,
                          NSError *_Nullable error) {
                  handler(error);
                }];
}

#pragma mark - Study Materials

- (void)getStudyMaterialsModifiedAfter:(NSString *_Nullable)date
                       progressHandler:(PartialCompletionHandler)progressHandler
                               handler:(StudyMaterialsHandler)handler {
  NSMutableArray<TKMStudyMaterials *> *ret = [NSMutableArray array];

  NSURLComponents *url = [NSURLComponents
      componentsWithString:[NSString stringWithFormat:@"%s/study_materials", kURLBase]];
  if (date && date.length) {
    [url setQueryItems:@[
      [NSURLQueryItem queryItemWithName:@"updated_after" value:date],
    ]];
  }

  [self startPagedQueryFor:url.URL
                   handler:^(NSString *dataUpdatedAt, NSArray *data, int page, int totalPages,
                             NSError *error) {
                     if (error) {
                       progressHandler(1, 1);
                       handler(error, nil, nil);
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

                     progressHandler(page, totalPages);
                     if (page == totalPages) {
                       handler(nil, dataUpdatedAt, ret);
                     }
                   }];
}

- (void)updateStudyMaterial:(TKMStudyMaterials *)material
                    handler:(UpdateStudyMaterialHandler)handler {
  NSURL *queryURL =
      [NSURL URLWithString:[NSString stringWithFormat:@"%s/study_materials?subject_ids=%d",
                                                      kURLBase, material.subjectId]];

  // We need to check if the study material exists already.
  [self startPagedQueryFor:queryURL
                   handler:^(NSString *dataUpdatedAt, NSArray *_Nullable response, int page,
                             int totalPages, NSError *_Nullable error) {
                     if (error) {
                       handler(error);
                       return;
                     }

                     // Encode the data to send in the request.
                     NSMutableDictionary *studyMaterial = [NSMutableDictionary dictionary];
                     [studyMaterial setObject:material.meaningSynonymsArray
                                       forKey:@"meaning_synonyms"];

                     NSMutableDictionary *payload = [NSMutableDictionary dictionary];
                     [payload setObject:studyMaterial forKey:@"study_material"];

                     NSString *urlString;
                     NSString *method;
                     if (response.count) {
                       int materialID = [response[0][@"id"] intValue];
                       urlString = [NSString
                           stringWithFormat:@"%s/study_materials/%d", kURLBase, materialID];
                       method = @"PUT";
                     } else {
                       [studyMaterial setObject:@(material.subjectId) forKey:@"subject_id"];
                       urlString = [NSString stringWithFormat:@"%s/study_materials", kURLBase];
                       method = @"POST";
                     }

                     NSData *data = [NSJSONSerialization dataWithJSONObject:payload
                                                                    options:0
                                                                      error:nil];
                     [self submitJSONToURL:[NSURL URLWithString:urlString]
                                withMethod:method
                                      data:data
                                   handler:^(NSString *dataUpdatedAt, id _Nullable data, int page,
                                             int totalPages, NSError *_Nullable error) {
                                     handler(error);
                                   }];
                   }];
}

#pragma mark - User Info

- (void)getUserInfo:(UserInfoHandler)handler {
  NSURLComponents *url =
      [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%s/user", kURLBase]];

  [self startPagedQueryFor:url.URL
                   handler:^(NSString *dataUpdatedAt, NSDictionary *data, int page, int totalPages,
                             NSError *error) {
                     if (error) {
                       handler(error, nil);
                       return;
                     }

                     TKMUser *ret = [[TKMUser alloc] init];
                     ret.username = data[@"username"];
                     ret.level = [data[@"level"] intValue];
                     ret.profileURL = data[@"profile_url"];

                     NSDictionary<NSString *, id> *subscription = data[@"subscription"];
                     ret.maxLevelGrantedBySubscription =
                         [subscription[@"max_level_granted"] intValue];
                     ret.subscribed = [subscription[@"active"] boolValue];

                     if (subscription[@"period_ends_at"] != [NSNull null]) {
                       ret.subscriptionEndsAt = [[Client
                           parseISO8601Date:subscription[@"period_ends_at"]] timeIntervalSince1970];
                     }

                     if (data[@"started_at"] != [NSNull null]) {
                       ret.startedAt =
                           [[Client parseISO8601Date:data[@"started_at"]] timeIntervalSince1970];
                     }

                     if (data[@"current_vacation_started_at"] != [NSNull null]) {
                       ret.vacationStartedAt =
                           [[Client parseISO8601Date:data[@"current_vacation_started_at"]]
                               timeIntervalSince1970];
                     }

                     handler(nil, ret);
                   }];
}

- (void)getLevelTimes:(LevelInfoHandler)handler {
  NSURLComponents *url = [NSURLComponents
      componentsWithString:[NSString stringWithFormat:@"%s/level_progressions", kURLBase]];

  NSMutableArray<TKMLevel *> *levels = [NSMutableArray array];
  [self startPagedQueryFor:url.URL
                   handler:^(NSString *dataUpdatedAt, NSDictionary *data, int page, int totalPages,
                             NSError *error) {
                     if (error) {
                       handler(error, nil);
                       return;
                     }

                     for (NSDictionary *d in data) {
                       TKMLevel *level = [TKMLevel message];
                       level.id_p = [d[@"id"] intValue];
                       level.level = [d[@"data"][@"level"] intValue];

                       if (d[@"data"][@"abandoned_at"] != [NSNull null]) {
                         level.abandonedAt = [[Client parseISO8601Date:d[@"data"][@"abandoned_at"]]
                             timeIntervalSince1970];
                       }

                       if (d[@"data"][@"completed_at"] != [NSNull null]) {
                         level.completedAt = [[Client parseISO8601Date:d[@"data"][@"completed_at"]]
                             timeIntervalSince1970];
                       }

                       if (d[@"data"][@"created_at"] != [NSNull null]) {
                         level.createdAt = [[Client parseISO8601Date:d[@"data"][@"created_at"]]
                             timeIntervalSince1970];
                       }

                       if (d[@"data"][@"passed_at"] != [NSNull null]) {
                         level.passedAt = [[Client parseISO8601Date:d[@"data"][@"passed_at"]]
                             timeIntervalSince1970];
                       }

                       if (d[@"data"][@"started_at"] != [NSNull null]) {
                         level.startedAt = [[Client parseISO8601Date:d[@"data"][@"started_at"]]
                             timeIntervalSince1970];
                       }

                       if (d[@"data"][@"unlocked_at"] != [NSNull null]) {
                         level.unlockedAt = [[Client parseISO8601Date:d[@"data"][@"unlocked_at"]]
                             timeIntervalSince1970];
                       }

                       [levels addObject:level];
                     }

                     if (page == totalPages) {
                       handler(nil, levels);
                     }
                   }];
}

@end

NS_ASSUME_NONNULL_END
