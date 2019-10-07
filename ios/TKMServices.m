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

#import "TKMServices+Internals.h"

#import "Reachability.h"
#import "TKMAudio.h"
#import "TKMFontLoader.h"
#import "Tsurukame-Swift.h"

@interface TKMServices ()

@property(nonatomic, readwrite, nullable) LocalCachingClient *localCachingClient;

@end

@implementation TKMServices

- (instancetype)init {
  self = [super init];
  if (self) {
    _dataLoader = [[DataLoader alloc] initFromURL:[[NSBundle mainBundle] URLForResource:@"data"
                                                                          withExtension:@"bin"]
                                            error:nil];
    _reachability = [Reachability reachabilityForInternetConnection];
    _audio = [[TKMAudio alloc] initWithServices:self];
    _fontLoader = [[TKMFontLoader alloc] init];
  }
  return self;
}

@end
