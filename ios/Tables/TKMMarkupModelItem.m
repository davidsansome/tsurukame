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

#import "TKMMarkupModelItem.h"

static UIColor *kRadicalBackgroundColor;
static UIColor *kKanjiBackgroundColor;
static UIColor *kVocabularyBackgroundColor;

static NSAttributedString *AttributedStringForFormattedText(
    TKMFormattedText *formattedText, NSDictionary<NSAttributedStringKey, id> *standardAttributes) {
  NSMutableDictionary<NSAttributedStringKey, id> *attributes = [NSMutableDictionary dictionary];

  if (standardAttributes) {
    [attributes addEntriesFromDictionary:standardAttributes];
  }

  for (int i = 0; i < formattedText.formatArray.count; i++) {
    TKMFormattedText_Format format = [formattedText.formatArray valueAtIndex:i];
    switch (format) {
      case TKMFormattedText_Format_Kanji:
        [attributes setValue:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
        [attributes setValue:kKanjiBackgroundColor forKey:NSBackgroundColorAttributeName];
        break;
      case TKMFormattedText_Format_Radical:
        [attributes setValue:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
        [attributes setValue:kRadicalBackgroundColor forKey:NSBackgroundColorAttributeName];
        break;
      case TKMFormattedText_Format_Vocabulary:
        [attributes setValue:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
        [attributes setValue:kVocabularyBackgroundColor forKey:NSBackgroundColorAttributeName];
        break;
      case TKMFormattedText_Format_Reading:
        if (@available(iOS 13.0, *)) {
          [attributes setValue:[UIColor secondaryLabelColor] forKey:NSBackgroundColorAttributeName];
          [attributes setValue:[UIColor systemBackgroundColor] forKey:NSForegroundColorAttributeName];
        } else {
          [attributes setValue:[UIColor darkGrayColor] forKey:NSBackgroundColorAttributeName];
          [attributes setValue:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
        }
        break;
      case TKMFormattedText_Format_Japanese:
        break;
      case TKMFormattedText_Format_Bold: {
        UIFont *font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
        [attributes setValue:font forKey:NSFontAttributeName];
        break;
      }
      case TKMFormattedText_Format_Italic: {
        UIFont *font = [UIFont italicSystemFontOfSize:[UIFont systemFontSize]];
        [attributes setValue:font forKey:NSFontAttributeName];
        break;
      }
      case TKMFormattedText_Format_Link:
        [attributes setValue:formattedText.linkURL forKey:NSLinkAttributeName];
        break;
    }
  }

  return [[NSAttributedString alloc] initWithString:formattedText.text attributes:attributes];
}

NSMutableAttributedString *TKMRenderFormattedText(
    NSArray<TKMFormattedText *> *formattedText,
    NSDictionary<NSAttributedStringKey, id> *standardAttributes) {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kRadicalBackgroundColor = [UIColor colorWithRed:0.839 green:0.945 blue:1 alpha:1];  // #d6f1ff
    kKanjiBackgroundColor = [UIColor colorWithRed:1 green:0.839 blue:0.945 alpha:1];    // #ffd6f1
    kVocabularyBackgroundColor = [UIColor colorWithRed:0.945
                                                 green:0.839
                                                  blue:1
                                                 alpha:1];  // #f1d6ff
  });

  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
  for (TKMFormattedText *part in formattedText) {
    [text appendAttributedString:AttributedStringForFormattedText(part, standardAttributes)];
  }
  return text;
}
