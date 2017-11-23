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

- (void)getAllAssignments:(AssignmentHandler)handler {
  NSMutableArray<WKAssignment *> *ret = [NSMutableArray array];
  
  void (^completionHandler)(NSData * _Nullable data,
                            NSURLResponse * _Nullable response,
                            NSError * _Nullable error) = ^void(NSData * _Nullable data,
                                                               NSURLResponse * _Nullable response,
                                                               NSError * _Nullable error) {
    if (error != nil) {
      handler(error, nil);
      return;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error != nil) {
      handler(error, nil);
      return;
    }
    if (dict[@"error"] != nil) {
      handler([NSError errorWithDomain:WKClientErrorDomain
                                  code:0
                              userInfo:@{NSLocalizedDescriptionKey: dict[@"error"]}], nil);
      return;
    }
    
    NSString *nextURLString = dict[@"pages"][@"next_url"];
    if (nextURLString == nil) {
    }
    
    for (NSDictionary *data in dict[@"data"]) {
      WKAssignment *assignment = [[WKAssignment alloc] init];
      assignment.id_p = [data[@"id"] intValue];
      assignment.level = [data[@"data"][@"level"] intValue];
      assignment.subjectId = [data[@"data"][@"subject_id"] intValue];
      
      if (data[@"data"][@"available_at"] != [NSNull null]) {
        assignment.availableAt =
            [[_dateFormatter dateFromString:data[@"data"][@"available_at"]] timeIntervalSince1970];
      }
      
      NSString *subjectType = data[@"data"][@"subject_type"];
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
    
    // TODO: get next page.
    handler(nil, ret);
  };
  
  NSURLRequest *req =
      [self authorizeRequestForURL:
          [NSURL URLWithString:[NSString stringWithFormat:@"%s/assignments", kURLBase]]];
  NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:req
                                              completionHandler:completionHandler];
  [task resume];
}

@end
