//
//  Client.m
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "Client.h"

static const char *kURLBase = "https://www.wanikani.com/api/v2";

@implementation Client {
  NSString *_apiToken;
  NSURLSession *_urlSession;
}

- (instancetype)initWithApiToken:(NSString *)apiToken {
  if (self = [super init]) {
    _apiToken = apiToken;
    _urlSession = [NSURLSession sharedSession];
  }
  return self;
}

- (void)getAllAssignments:(AssignmentHandler *)handler {
  NSArray<WKAssignment *> *ret = [NSArray array];
  
  NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%s/assignments", kURLBase]];
  [_urlSession dataTaskWithURL:url
             completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
               NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
               NSString *nextURLString = dict[@"pages"][@"next_url"];
               if (nextURLString == nil) {
               }
               
               for (NSDictionary *data in dict[@"data"]) {
                 WKAssignment *assignment = [[WKAssignment alloc] init];
                 assignment.id_p = data[@"id"];
                 assignment.level = data[@"data"][@"level"];
                 assignment.subjectId = data[@"data"][@"subject_id"];
                 
                 if (data[@"data"][@"subject_type"] == @"radical") {
                   assignment.subjectType = 1;
                 }
               }
             }
   ];
}

@end
