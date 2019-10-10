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

#import "TKMKanaInput.h"
#import "Settings.h"
#import "TKMKanaInput+Internals.h"

NS_ASSUME_NONNULL_BEGIN

void EnsureInitialised() {
  dispatch_once(&sOnceToken, ^{
    kReplacements = @{
      @"a" : @"\u3042",
      @"ba" : @"\u3070",
      @"be" : @"\u3079",
      @"bi" : @"\u3073",
      @"bo" : @"\u307c",
      @"bu" : @"\u3076",
      @"bya" : @"\u3073\u3083",
      @"bye" : @"\u3073\u3047",
      @"byi" : @"\u3073\u3043",
      @"byo" : @"\u3073\u3087",
      @"byu" : @"\u3073\u3085",
      @"ca" : @"\u304b",
      @"ce" : @"\u3051",
      @"cha" : @"\u3061\u3083",
      @"che" : @"\u3061\u3047",
      @"chi" : @"\u3061",
      @"cho" : @"\u3061\u3087",
      @"chu" : @"\u3061\u3085",
      @"chya" : @"\u3061\u3083",
      @"chye" : @"\u3061\u3047",
      @"chyo" : @"\u3061\u3087",
      @"chyu" : @"\u3061\u3085",
      @"ci" : @"\u304d",
      @"co" : @"\u3053",
      @"cu" : @"\u304f",
      @"cya" : @"\u3061\u3083",
      @"cye" : @"\u3061\u3047",
      @"cyi" : @"\u3061\u3043",
      @"cyo" : @"\u3061\u3087",
      @"cyu" : @"\u3061\u3085",
      @"da" : @"\u3060",
      @"de" : @"\u3067",
      @"dha" : @"\u3067\u3083",
      @"dhe" : @"\u3067\u3047",
      @"dhi" : @"\u3067\u3043",
      @"dho" : @"\u3067\u3087",
      @"dhu" : @"\u3067\u3085",
      @"di" : @"\u3062",
      @"do" : @"\u3069",
      @"du" : @"\u3065",
      @"dwa" : @"\u3069\u3041",
      @"dwe" : @"\u3069\u3047",
      @"dwi" : @"\u3069\u3043",
      @"dwo" : @"\u3069\u3049",
      @"dwu" : @"\u3069\u3045",
      @"dya" : @"\u3062\u3083",
      @"dye" : @"\u3062\u3047",
      @"dyi" : @"\u3062\u3043",
      @"dyo" : @"\u3062\u3087",
      @"dyu" : @"\u3062\u3085",
      @"e" : @"\u3048",
      @"fa" : @"\u3075\u3041",
      @"fe" : @"\u3075\u3047",
      @"fi" : @"\u3075\u3043",
      @"fo" : @"\u3075\u3049",
      @"fu" : @"\u3075",
      @"fwa" : @"\u3075\u3041",
      @"fwe" : @"\u3075\u3047",
      @"fwi" : @"\u3075\u3043",
      @"fwo" : @"\u3075\u3049",
      @"fwu" : @"\u3075\u3045",
      @"fya" : @"\u3075\u3083",
      @"fye" : @"\u3075\u3047",
      @"fyi" : @"\u3075\u3043",
      @"fyo" : @"\u3075\u3087",
      @"fyu" : @"\u3075\u3085",
      @"ga" : @"\u304c",
      @"ge" : @"\u3052",
      @"gi" : @"\u304e",
      @"go" : @"\u3054",
      @"gu" : @"\u3050",
      @"gwa" : @"\u3050\u3041",
      @"gwe" : @"\u3050\u3047",
      @"gwi" : @"\u3050\u3043",
      @"gwo" : @"\u3050\u3049",
      @"gwu" : @"\u3050\u3045",
      @"gya" : @"\u304e\u3083",
      @"gye" : @"\u304e\u3047",
      @"gyi" : @"\u304e\u3043",
      @"gyo" : @"\u304e\u3087",
      @"gyu" : @"\u304e\u3085",
      @"ha" : @"\u306f",
      @"he" : @"\u3078",
      @"hi" : @"\u3072",
      @"ho" : @"\u307b",
      @"hu" : @"\u3075",
      @"hya" : @"\u3072\u3083",
      @"hye" : @"\u3072\u3047",
      @"hyi" : @"\u3072\u3043",
      @"hyo" : @"\u3072\u3087",
      @"hyu" : @"\u3072\u3085",
      @"i" : @"\u3044",
      @"ja" : @"\u3058\u3083",
      @"je" : @"\u3058\u3047",
      @"ji" : @"\u3058",
      @"jo" : @"\u3058\u3087",
      @"ju" : @"\u3058\u3085",
      @"jya" : @"\u3058\u3083",
      @"jye" : @"\u3058\u3047",
      @"jyi" : @"\u3058\u3043",
      @"jyo" : @"\u3058\u3087",
      @"jyu" : @"\u3058\u3085",
      @"ka" : @"\u304b",
      @"ke" : @"\u3051",
      @"ki" : @"\u304d",
      @"ko" : @"\u3053",
      @"ku" : @"\u304f",
      @"kwa" : @"\u304f\u3041",
      @"kya" : @"\u304d\u3083",
      @"kye" : @"\u304d\u3047",
      @"kyi" : @"\u304d\u3043",
      @"kyo" : @"\u304d\u3087",
      @"kyu" : @"\u304d\u3085",
      @"la" : @"\u3089",
      @"lca" : @"\u30f5",
      @"lce" : @"\u30f6",
      @"le" : @"\u308c",
      @"li" : @"\u308a",
      @"lka" : @"\u30f5",
      @"lke" : @"\u30f6",
      @"lo" : @"\u308d",
      @"ltsu" : @"\u3063",
      @"ltu" : @"\u3063",
      @"lu" : @"\u308b",
      @"lwe" : @"\u308e",
      @"lya" : @"\u308a\u3083",
      @"lye" : @"\u308a\u3047",
      @"lyi" : @"\u308a\u3043",
      @"lyo" : @"\u308a\u3087",
      @"lyu" : @"\u308a\u3085",
      @"ma" : @"\u307e",
      @"me" : @"\u3081",
      @"mi" : @"\u307f",
      @"mo" : @"\u3082",
      @"mu" : @"\u3080",
      @"mya" : @"\u307f\u3083",
      @"mye" : @"\u307f\u3047",
      @"myi" : @"\u307f\u3043",
      @"myo" : @"\u307f\u3087",
      @"myu" : @"\u307f\u3085",
      @"n " : @"\u3093",
      @"na" : @"\u306a",
      @"ne" : @"\u306d",
      @"ni" : @"\u306b",
      @"nn" : @"\u3093",
      @"no" : @"\u306e",
      @"nu" : @"\u306c",
      @"nya" : @"\u306b\u3083",
      @"nye" : @"\u306b\u3047",
      @"nyi" : @"\u306b\u3043",
      @"nyo" : @"\u306b\u3087",
      @"nyu" : @"\u306b\u3085",
      @"o" : @"\u304a",
      @"pa" : @"\u3071",
      @"pe" : @"\u307a",
      @"pi" : @"\u3074",
      @"po" : @"\u307d",
      @"pu" : @"\u3077",
      @"pya" : @"\u3074\u3083",
      @"pye" : @"\u3074\u3047",
      @"pyi" : @"\u3074\u3043",
      @"pyo" : @"\u3074\u3087",
      @"pyu" : @"\u3074\u3085",
      @"qa" : @"\u304f\u3041",
      @"qe" : @"\u304f\u3047",
      @"qi" : @"\u304f\u3043",
      @"qo" : @"\u304f\u3049",
      @"qwa" : @"\u304f\u3041",
      @"qwe" : @"\u304f\u3047",
      @"qwi" : @"\u304f\u3043",
      @"qwo" : @"\u304f\u3049",
      @"qwu" : @"\u304f\u3045",
      @"qya" : @"\u304f\u3083",
      @"qye" : @"\u304f\u3047",
      @"qyi" : @"\u304f\u3043",
      @"qyo" : @"\u304f\u3087",
      @"qyu" : @"\u304f\u3085",
      @"ra" : @"\u3089",
      @"re" : @"\u308c",
      @"ri" : @"\u308a",
      @"ro" : @"\u308d",
      @"ru" : @"\u308b",
      @"rya" : @"\u308a\u3083",
      @"rye" : @"\u308a\u3047",
      @"ryi" : @"\u308a\u3043",
      @"ryo" : @"\u308a\u3087",
      @"ryu" : @"\u308a\u3085",
      @"sa" : @"\u3055",
      @"se" : @"\u305b",
      @"sha" : @"\u3057\u3083",
      @"she" : @"\u3057\u3047",
      @"shi" : @"\u3057",
      @"sho" : @"\u3057\u3087",
      @"shu" : @"\u3057\u3085",
      @"shya" : @"\u3057\u3083",
      @"shye" : @"\u3057\u3047",
      @"shyo" : @"\u3057\u3087",
      @"shyu" : @"\u3057\u3085",
      @"si" : @"\u3057",
      @"so" : @"\u305d",
      @"su" : @"\u3059",
      @"swa" : @"\u3059\u3041",
      @"swe" : @"\u3059\u3047",
      @"swi" : @"\u3059\u3043",
      @"swo" : @"\u3059\u3049",
      @"swu" : @"\u3059\u3045",
      @"sya" : @"\u3057\u3083",
      @"sye" : @"\u3057\u3047",
      @"syi" : @"\u3057\u3043",
      @"syo" : @"\u3057\u3087",
      @"syu" : @"\u3057\u3085",
      @"ta" : @"\u305f",
      @"te" : @"\u3066",
      @"tha" : @"\u3066\u3083",
      @"the" : @"\u3066\u3047",
      @"thi" : @"\u3066\u3043",
      @"tho" : @"\u3066\u3087",
      @"thu" : @"\u3066\u3085",
      @"ti" : @"\u3061",
      @"to" : @"\u3068",
      @"tsa" : @"\u3064\u3041",
      @"tse" : @"\u3064\u3047",
      @"tsi" : @"\u3064\u3043",
      @"tso" : @"\u3064\u3049",
      @"tsu" : @"\u3064",
      @"tu" : @"\u3064",
      @"twa" : @"\u3068\u3041",
      @"twe" : @"\u3068\u3047",
      @"twi" : @"\u3068\u3043",
      @"two" : @"\u3068\u3049",
      @"twu" : @"\u3068\u3045",
      @"tya" : @"\u3061\u3083",
      @"tye" : @"\u3061\u3047",
      @"tyi" : @"\u3061\u3043",
      @"tyo" : @"\u3061\u3087",
      @"tyu" : @"\u3061\u3085",
      @"u" : @"\u3046",
      @"va" : @"\u3094\u3041",
      @"ve" : @"\u3094\u3047",
      @"vi" : @"\u3094\u3043",
      @"vo" : @"\u3094\u3049",
      @"vu" : @"\u3094",
      @"vya" : @"\u3094\u3083",
      @"vye" : @"\u3094\u3047",
      @"vyi" : @"\u3094\u3043",
      @"vyo" : @"\u3094\u3087",
      @"vyu" : @"\u3094\u3085",
      @"wa" : @"\u308f",
      @"we" : @"\u3046\u3047",
      @"wha" : @"\u3046\u3041",
      @"whe" : @"\u3046\u3047",
      @"whi" : @"\u3046\u3043",
      @"who" : @"\u3046\u3049",
      @"whu" : @"\u3046",
      @"wi" : @"\u3046\u3043",
      @"wo" : @"\u3092",
      @"wu" : @"\u3046",
      @"xa" : @"\u3041",
      @"xca" : @"\u30f5",
      @"xce" : @"\u30f6",
      @"xe" : @"\u3047",
      @"xi" : @"\u3043",
      @"xka" : @"\u30f5",
      @"xke" : @"\u30f6",
      @"xn" : @"\u3093",
      @"xo" : @"\u3049",
      @"xtu" : @"\u3063",
      @"xu" : @"\u3045",
      @"xwa" : @"\u308e",
      @"xya" : @"\u3083",
      @"xye" : @"\u3047",
      @"xyi" : @"\u3043",
      @"xyo" : @"\u3087",
      @"xyu" : @"\u3085",
      @"ya" : @"\u3084",
      @"ye" : @"\u3044\u3047",
      @"yi" : @"\u3044",
      @"yo" : @"\u3088",
      @"yu" : @"\u3086",
      @"za" : @"\u3056",
      @"ze" : @"\u305c",
      @"zi" : @"\u3058",
      @"zo" : @"\u305e",
      @"zu" : @"\u305a",
      @"zya" : @"\u3058\u3083",
      @"zye" : @"\u3058\u3047",
      @"zyi" : @"\u3058\u3043",
      @"zyo" : @"\u3058\u3087",
      @"zyu" : @"\u3058\u3085",
      @"-" : @"ー",
    };

    kConsonants = [NSCharacterSet characterSetWithCharactersInString:@"bcdfghjklmnpqrstvwxyz"];
    kN = [NSCharacterSet characterSetWithCharactersInString:@"nm"];
    kCanFollowN = [NSCharacterSet characterSetWithCharactersInString:@"aiueony"];
  });
}

NSString *TKMConvertKanaText(NSString *input) {
  EnsureInitialised();

  NSMutableString *ret = [NSMutableString stringWithString:input];
  for (int i = 0; i < ret.length; ++i) {
    if (i > 0) {
      unichar currentChar = [ret characterAtIndex:i];
      unichar lastChar = [ret characterAtIndex:i - 1];
      if (currentChar != 'n' && currentChar == lastChar &&
          [kConsonants characterIsMember:currentChar] && [kConsonants characterIsMember:lastChar]) {
        [ret replaceCharactersInRange:NSMakeRange(i - 1, 1) withString:@"っ"];
        continue;
      }
    }

    // Test for replacements.
    for (int len = 4; len > 0; --len) {
      if (len > i + 1) {
        continue;
      }
      NSRange replacementRange = NSMakeRange(i - len + 1, len);
      NSString *text = [ret substringWithRange:replacementRange];
      NSString *replacement = kReplacements[text];
      if (replacement) {
        [ret replaceCharactersInRange:replacementRange withString:replacement];
        i -= len - 1;
        break;
      }
    }
  }

  // Replace n/m and remove anything that isn't kana.
  for (int i = 0; i < ret.length; ++i) {
    if ([kN characterIsMember:[ret characterAtIndex:i]]) {
      [ret replaceCharactersInRange:NSMakeRange(i, 1) withString:@"ん"];
      continue;
    }
  }
  for (int i = (int)ret.length - 1; i >= 0; --i) {
    if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:[ret characterAtIndex:i]]) {
      [ret deleteCharactersInRange:NSMakeRange(i, 1)];
    } else {
      break;
    }
  }
  return ret;
}

@implementation TKMKanaInput {
  __weak id<UITextFieldDelegate> _delegate;
}

- (instancetype)initWithDelegate:(id<UITextFieldDelegate>)delegate {
  EnsureInitialised();
  self = [super init];
  if (self) {
    _delegate = delegate;
  }
  return self;
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
  [_delegate textField:textField shouldChangeCharactersInRange:range replacementString:string];
  if (!_enabled || range.length != 0 || string.length == 0) {
    return YES;
  }

  if (range.location > 0 && string.length == 1) {
    unichar newChar = [string characterAtIndex:0];
    unichar lastChar = [textField.text characterAtIndex:range.location - 1];

    BOOL lastCharWasUppercase =
        [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:lastChar];

    newChar = tolower(newChar);
    lastChar = tolower(lastChar);

    // Test for sokuon.
    if (![kN characterIsMember:newChar] && newChar == lastChar &&
        [kConsonants characterIsMember:newChar] && [kConsonants characterIsMember:lastChar]) {
      NSString *replacementString =
          (lastCharWasUppercase || _alphabet == kTKMAlphabetKatakana) ? @"ッ" : @"っ";
      textField.text =
          [textField.text stringByReplacingCharactersInRange:NSMakeRange(range.location - 1, 1)
                                                  withString:replacementString];
      return YES;
    }

    // Replace n followed by a consonant.
    if (newChar != 'n' && [kN characterIsMember:lastChar] &&
        ![kCanFollowN characterIsMember:newChar]) {
      NSString *replacementString =
          (lastCharWasUppercase || _alphabet == kTKMAlphabetKatakana) ? @"ン" : @"ん";
      textField.text =
          [textField.text stringByReplacingCharactersInRange:NSMakeRange(range.location - 1, 1)
                                                  withString:replacementString];
      return YES;
    }
  }

  // Test for replacements.
  for (int i = 3; i >= 0; --i) {
    if (i > range.location) {
      continue;
    }
    NSRange replacementRange = NSMakeRange(range.location - i, i);
    NSString *text = [NSString
        stringWithFormat:@"%@%@", [textField.text substringWithRange:replacementRange], string];

    BOOL firstCharacterIsUppercase =
        [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[text characterAtIndex:0]];
    text = [text lowercaseString];

    NSString *replacement = kReplacements[text];
    if (replacement) {
      if (firstCharacterIsUppercase || _alphabet == kTKMAlphabetKatakana) {
        replacement = [replacement stringByApplyingTransform:NSStringTransformHiraganaToKatakana
                                                     reverse:NO];
      }
      textField.text = [textField.text stringByReplacingCharactersInRange:replacementRange
                                                               withString:replacement];
      return NO;
    }
  }
  return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  return [_delegate textFieldShouldReturn:textField];
}

@end

NS_ASSUME_NONNULL_END
