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

#import "WKOpenURL.h"

static NSString * const kGoogleChromeHTTPScheme = @"googlechrome:";
static NSString * const kGoogleChromeHTTPSScheme = @"googlechromes:";

static BOOL IsChromeInstalled() {
  NSURL *simpleURL = [NSURL URLWithString:kGoogleChromeHTTPScheme];
  return [[UIApplication sharedApplication] canOpenURL:simpleURL];
}

static BOOL OpenInChrome(NSURL *url) {
  if (IsChromeInstalled()) {
    NSString *scheme = [url.scheme lowercaseString];
    // Replace the URL Scheme with the Chrome equivalent.
    NSString *chromeScheme = nil;
    if ([scheme isEqualToString:@"http"]) {
      chromeScheme = kGoogleChromeHTTPScheme;
    } else if ([scheme isEqualToString:@"https"]) {
      chromeScheme = kGoogleChromeHTTPSScheme;
    }
    
    // Proceed only if a valid Google Chrome URI Scheme is available.
    if (chromeScheme) {
      NSString *absoluteString = [url absoluteString];
      NSRange rangeForScheme = [absoluteString rangeOfString:@":"];
      NSString *urlNoScheme =
      [absoluteString substringFromIndex:rangeForScheme.location + 1];
      NSString *chromeURLString =
      [chromeScheme stringByAppendingString:urlNoScheme];
      NSURL *chromeURL = [NSURL URLWithString:chromeURLString];
      // Open the URL with Google Chrome.
      [[UIApplication sharedApplication] openURL:chromeURL options:@{} completionHandler:nil];
      return YES;
    }
  }
  return NO;
}

void WKOpenURL(NSURL *url) {
  if (!OpenInChrome(url)) {
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
  }
}

