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

#import "NSString+LevenshteinDistance.h"

static NSInteger SmallestOf3(NSInteger a, NSInteger b, NSInteger c) {
  NSInteger min = a;
  if (b < min) {
    min = b;
  }
  if (c < min) {
    min = c;
  }
  return min;
}

static NSInteger SmallestOf2(NSInteger a, NSInteger b) { return a <= b ? a : b; }

@implementation NSString (LevenshteinDistance)

- (float)levenshteinDistanceTo:(NSString *)other {
  if (self.length == 0) {
    return other.length;
  }
  if (other.length == 0) {
    return self.length;
  }

  // Step 1 (Steps follow description at http://www.merriampark.com/ld.htm)
  NSInteger n = [self length] + 1;
  NSInteger m = [other length] + 1;

  NSInteger *d = malloc(sizeof(NSInteger) * m * n);

  for (int k = 0; k < n; k++) {
    d[k] = k;
  }

  for (int k = 0; k < m; k++) {
    d[k * n] = k;
  }

  for (int i = 1; i < n; i++) {
    for (int j = 1; j < m; j++) {
      NSInteger cost = [self characterAtIndex:i - 1] == [other characterAtIndex:j - 1] ? 0 : 1;

      d[j * n + i] =
          SmallestOf3(d[(j - 1) * n + i] + 1, d[j * n + i - 1] + 1, d[(j - 1) * n + i - 1] + cost);

      // This conditional adds Damerau transposition to Levenshtein distance
      if (i > 1 && j > 1 && [self characterAtIndex:i - 1] == [other characterAtIndex:j - 2] &&
          [self characterAtIndex:i - 2] == [other characterAtIndex:j - 1]) {
        d[j * n + i] = SmallestOf2(d[j * n + i], d[(j - 2) * n + i - 2] + cost);
      }
    }
  }

  NSInteger distance = d[n * m - 1];

  free(d);

  return distance;
}

@end
