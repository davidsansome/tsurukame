//
//  Client.m
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "Client.h"

static const char *kURLBase = "https://www.wanikani.com/api/v2";
const NSString *WKClientErrorDomain = @"WKClientErrorDomain";

typedef void(^PartialResponseHandler)(NSArray *data, NSError *error);

@implementation Client {
  NSString *_apiToken;
  NSURLSession *_urlSession;
  NSDateFormatter *_dateFormatter;
}

- (instancetype)initWithApiToken:(NSString *)apiToken {
  if (self = [super init]) {
    _apiToken = apiToken;
    _urlSession = [NSURLSession sharedSession];
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"];
  }
  return self;
}

- (NSURLRequest *)authorizeRequestForURL:(NSURL *)url {
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"Token token=%@", _apiToken]
      forHTTPHeaderField:@"Authorization"];
  return req;
}

- (void)startPagedQueryFor:(NSURL *)url
                   handler:(PartialResponseHandler)handler {
  NSURLRequest *req = [self authorizeRequestForURL:url];
  NSLog(@"Request: %@", url);
  NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:req
                                              completionHandler:^(NSData * _Nullable data,
                                                                  NSURLResponse * _Nullable response,
                                                                  NSError * _Nullable error) {
                                                [self parseJsonResponse:data
                                                                  error:error
                                                                handler:handler];
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
    handler(nil, [NSError errorWithDomain:WKClientErrorDomain
                                     code:0
                                 userInfo:@{NSLocalizedDescriptionKey: dict[@"error"]}]);
    return;
  }
  
  handler(dict[@"data"], nil);
  
  // Get the next page if we have one.
  if (dict[@"pages"][@"next_url"] != [NSNull null]) {
    NSString *nextURLString = dict[@"pages"][@"next_url"];
    NSLog(@"Request: %@", nextURLString);
    NSURLRequest *req = [self authorizeRequestForURL:[NSURL URLWithString:nextURLString]];
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:req
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

- (void)getAllAssignments:(AssignmentHandler)handler {
  NSMutableArray<WKAssignment *> *ret = [NSMutableArray array];
  
  NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%s/assignments", kURLBase]];
  [self startPagedQueryFor:url handler:^(NSArray *data, NSError *error) {
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
      
      if (d[@"data"][@"available_at"] != [NSNull null]) {
        assignment.availableAt =
            [[_dateFormatter dateFromString:d[@"data"][@"available_at"]] timeIntervalSince1970];
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

@end
