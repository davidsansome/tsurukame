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
#import "Tsurukame-Swift.h"

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
        [attributes setValue:[TKMStyle kanjiBackgroundColor] forKey:NSBackgroundColorAttributeName];
        break;
      case TKMFormattedText_Format_Radical:
        [attributes setValue:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
        [attributes setValue:[TKMStyle radicalBackgroundColor]
                      forKey:NSBackgroundColorAttributeName];
        break;
      case TKMFormattedText_Format_Vocabulary:
        [attributes setValue:[UIColor blackColor] forKey:NSForegroundColorAttributeName];
        [attributes setValue:[TKMStyle vocabularyBackgroundColor]
                      forKey:NSBackgroundColorAttributeName];
        break;
      case TKMFormattedText_Format_Reading:
        [attributes setValue:TKMStyleColor.grey33 forKey:NSBackgroundColorAttributeName];
        [attributes setValue:TKMStyleColor.background forKey:NSForegroundColorAttributeName];
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
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
  for (TKMFormattedText *part in formattedText) {
    [text appendAttributedString:AttributedStringForFormattedText(part, standardAttributes)];
  }
  return text;
}
