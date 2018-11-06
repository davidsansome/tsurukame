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

#import "NSMutableArray+Shuffle.h"

@implementation NSMutableArray (Shuffle)

- (void)shuffle {
  NSUInteger count = [self count];
  if (count <= 1) {
    return;
  }

  for (NSUInteger i = 0; i < count - 1; ++i) {
    NSInteger remainingCount = count - i;
    NSInteger exchangeIndex = i + arc4random_uniform((u_int32_t)remainingCount);
    [self exchangeObjectAtIndex:i withObjectAtIndex:exchangeIndex];
  }
}

@end
