//
//  LanguageSpecificTextField.m
//  Wordlist
//
//  Created by David Sansome on 27/7/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "LanguageSpecificTextField.h"

@implementation LanguageSpecificTextField

- (UITextInputMode *)textInputMode {
  if (self.language) {
    for (UITextInputMode* tim in [UITextInputMode activeInputModes]) {
      if ([tim.primaryLanguage hasPrefix:self.language]) {
        return tim;
      }
    }
  }
  return [super textInputMode];
}

@end
