//
//  Client.m
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "Client.h"

static NSString *kURLBase = @"https://www.wanikani.com/api/v2";

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

- (id)getAllAssignments {
  NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%s/assignments", kURLBase]];
  [_urlSession dataTaskWithURL:url
             completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    
  }]
}

@end
