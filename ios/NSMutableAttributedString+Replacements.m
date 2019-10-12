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

#import "NSMutableAttributedString+Replacements.h"

@implementation NSMutableAttributedString (Replacements)

- (NSMutableAttributedString *)replaceFontSize:(CGFloat)newSize {
  void (^block)(id value, NSRange range, BOOL *stop) = ^(id value, NSRange range, BOOL *stop) {
    UIFont *font = (UIFont *)value;
    UIFont *newFont;
    if (font) {
      newFont = [UIFont fontWithDescriptor:font.fontDescriptor size:newSize];
    } else {
      newFont = [UIFont systemFontOfSize:newSize];
    }
    [self removeAttribute:NSFontAttributeName range:range];
    [self addAttribute:NSFontAttributeName value:newFont range:range];
  };

  [self beginEditing];
  [self enumerateAttribute:NSFontAttributeName
                   inRange:NSMakeRange(0, self.length)
                   options:0
                usingBlock:block];
  [self endEditing];

  return self;
}

- (NSMutableAttributedString *)replaceTextColor:(UIColor *)newColor {
  void (^block)(id value, NSRange range, BOOL *stop) = ^(id value, NSRange range, BOOL *stop) {
    [self removeAttribute:NSForegroundColorAttributeName range:range];
    [self addAttribute:NSForegroundColorAttributeName value:newColor range:range];
  };

  [self beginEditing];
  [self enumerateAttribute:NSForegroundColorAttributeName
                   inRange:NSMakeRange(0, self.length)
                   options:0
                usingBlock:block];
  [self endEditing];

  return self;
}

@end

@implementation NSAttributedString (Replacements)

- (NSAttributedString *)stringWithFontSize:(CGFloat)newSize {
  NSMutableAttributedString *ret =
      [[NSMutableAttributedString alloc] initWithAttributedString:self];
  [ret replaceFontSize:newSize];
  return ret;
}

- (NSAttributedString *)stringWithTextColor:(UIColor *)newColor {
  NSMutableAttributedString *ret =
      [[NSMutableAttributedString alloc] initWithAttributedString:self];
  [ret replaceTextColor:newColor];
  return ret;
}

@end
