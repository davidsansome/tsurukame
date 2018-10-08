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

#import <XCTest/XCTest.h>

#import "../TKMKanaInput.h"
#import "../TKMKanaInput+Internals.h"

@interface StubUITextFieldDelegate : NSObject <UITextFieldDelegate>
@end

@implementation StubUITextFieldDelegate

@end

@interface TKMKanaInputTest : XCTestCase

@end

@implementation TKMKanaInputTest {
  TKMKanaInput *_kanaInput;
  UITextField *_textField;
}

static NSCharacterSet *_tsuConsonants;
static NSArray *_tsuConsonantsArray;

+ (NSArray*)getCharactersFromCharacterSet:(NSCharacterSet*)charset {
  NSMutableArray *array = [NSMutableArray array];
  for (int plane = 0; plane <= 16; plane++) {
    if ([charset hasMemberInPlane:plane]) {
      UTF32Char c;
      for (c = plane << 16; c < (plane+1) << 16; c++) {
        if ([charset longCharacterIsMember:c]) {
          UTF32Char littleEndianChar = OSSwapHostToLittleInt32(c); // To make it byte-order safe
          NSString *s = [[NSString alloc] initWithBytes:&littleEndianChar length: sizeof(littleEndianChar) encoding:NSUTF32LittleEndianStringEncoding];
          [array addObject:s];
        }
      }
    }
  }
  return array;
}

+ (void)setUp {
  EnsureInitialised();
  
  //tsuConsonants = kConsonants - kN
  NSMutableCharacterSet *tsuConsonants = [[kN invertedSet] mutableCopy];
  [tsuConsonants formIntersectionWithCharacterSet:kConsonants];
  
  _tsuConsonants = tsuConsonants;
  _tsuConsonantsArray = [TKMKanaInputTest getCharactersFromCharacterSet:_tsuConsonants];
}

- (void)setUp {
  // Put setup code here. This method is called before the invocation of each test method in the class.
  StubUITextFieldDelegate *delegate = [[StubUITextFieldDelegate alloc] init];
  _kanaInput = [[TKMKanaInput alloc] initWithDelegate:delegate];
  _kanaInput.enabled = true;
  
  _textField = [[UITextField alloc] init];
}

- (void)testkReplacementsContainsOnlyValidCombinations {
  NSString *lastKey;
  for (NSString *key in [[kReplacements allKeys] sortedArrayUsingSelector:@selector(localizedCompare:)]) {
    if (lastKey) {
      XCTAssertFalse([key hasPrefix:lastKey]);
    }
    lastKey = key;
  }
}

- (void)testShouldChangeCharactersInRangeDoesNothingWhenDisabled {
  // when the _kanaInput is disabled shouldChangeCharactersInRange should return true and the text should be unchanged
  
  NSString *text = [_textField.text copy];
  
  _kanaInput.enabled = false;
  BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(0, 0) replacementString:@""];
  
  XCTAssertTrue(returnValue);
  XCTAssertEqualObjects(text, _textField.text);
}

- (void)testShouldChangeCharactersInRangeDoesNothingOnPaste {
  // when the length of the Range is greater 0 shouldChangeCharactersInRange should return true and the text should be unchanged
  
  NSString *text = [_textField.text copy];
  
  BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(0, 3) replacementString:@""];
  
  XCTAssertTrue(returnValue);
  XCTAssertEqualObjects(text, _textField.text);
}

- (void)testShouldChangeCharactersInRangeReplacesSameConsonantWithSokuon {
  // when there is a consonant and you type the same consonant it should be replaced by っ and the returnValue should be true
  
  for(NSString *consonant in _tsuConsonantsArray) {
    _textField.text = consonant;
    
    BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:consonant];
    
    XCTAssertTrue(returnValue);
    XCTAssertEqualObjects(@"っ", _textField.text);
  }
}

- (void)testShouldChangeCharactersInRangeReplacesNFollwedByConsonant {
  // when there is a n or m and you type a consonant it should be replaced by ん and the returnValue should be true
  
  NSArray *kNArray = [TKMKanaInputTest getCharactersFromCharacterSet:kN];
  
  for(NSString *consonant in _tsuConsonantsArray) {
    if(![kCanFollowN characterIsMember:[consonant characterAtIndex:0]]) {
      for(NSString *nm in kNArray) {
        _textField.text = nm;
        
        BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:consonant];
        
        XCTAssertTrue(returnValue);
        XCTAssertEqualObjects(@"ん", _textField.text);
      }
    }
  }
}

- (void)testShouldChangeCharactersInRangeReplacesRomanizationPatternsCorrectly {
  // when there is the start of a pattern and you type the last letter of the pattern it should be replaced by the given replacement and the returnValue should be false
  
  for(NSString *replacement in [kReplacements keyEnumerator]) {
    // this pattern is checked by another case...for this function it doesn't matter if it is in the kReplacements CharacterSet
    if([replacement isEqualToString:@"n "]) {
      continue;
    }
    
    NSString *lastReplacementCharacter = [replacement substringFromIndex:replacement.length - 1];
    
    _textField.text = [replacement substringToIndex:replacement.length - 1];
    
    BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(_textField.text.length, 0) replacementString: lastReplacementCharacter];
    XCTAssertFalse(returnValue);
    XCTAssertEqualObjects(kReplacements[replacement], _textField.text);
  }
}

- (void)testShouldChangeCharactersInRangeReplacesSameUppercaseConsonantWithKatakanaSokuon {
  // when you type a uppercase consonant followed by the same consonant, it should be replaced by ッ
  
  for(NSString *consonant in _tsuConsonantsArray) {
    NSString *uppercaseConsonant = [consonant uppercaseString];
    _textField.text = uppercaseConsonant;
    
    BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:uppercaseConsonant];
    
    XCTAssertTrue(returnValue);
    XCTAssertEqualObjects(@"ッ", _textField.text);
  }
}

- (void)testShouldChangeCharactersInRangeReplacesUppercaseNFollowedByConsonantWithKatakana {
  // when there is a N or M and you type a consonant it should be replaced by ン and the returnValue should be true
  
  NSArray *kNArray = [TKMKanaInputTest getCharactersFromCharacterSet:kN];
  
  for(NSString *consonant in _tsuConsonantsArray) {
    if(![kCanFollowN characterIsMember:[consonant characterAtIndex:0]]) {
      for(NSString *nm in kNArray) {
        _textField.text = [nm uppercaseString];
        
        BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:consonant];
        
        XCTAssertTrue(returnValue);
        XCTAssertEqualObjects(@"ン", _textField.text);
      }
    }
  }
}

- (void)testShouldChangeCharactersInRangeReplacesUppercaseRomanizationPatternsWithKatakana {
  // when there is the start of a pattern, the first letter of the patten is uppercase and you type the last letter of the pattern it should be replaced by the given replacement in katakana and the returnValue should be false
  
  for(NSString *replacement in [kReplacements keyEnumerator]) {
    // this pattern is checked by another case...for this function it doesn't matter if it is in the kReplacements CharacterSet
    if([replacement isEqualToString:@"n "]) {
      continue;
    }
    
    NSString *capitalizedReplacement = [replacement capitalizedString];
    
    NSString *lastReplacementCharacter = [capitalizedReplacement substringFromIndex:capitalizedReplacement.length - 1];
    
    
    _textField.text = [capitalizedReplacement substringToIndex:capitalizedReplacement.length - 1];
    
    BOOL returnValue = [_kanaInput textField:_textField shouldChangeCharactersInRange:NSMakeRange(_textField.text.length, 0) replacementString: lastReplacementCharacter];
    XCTAssertFalse(returnValue);
    XCTAssertEqualObjects(ConvertHiraganaToKatakana(kReplacements[replacement]), _textField.text);
  }
}

- (void)testConvertHiraganaToKatakanaConvertsAllTheHiraganaToKatakana {
  // hopefully I got all the combinations :D
  NSString *hiraganaInput = @"あいうえおかきくけこきゃきゅきょさしすせそしゃしゅしょたちつてとちゃちゅちょなにぬねのにゃにゅにょはひふへほひゃひゅひょまみむめもみゃみゅみょやゆよらりるれろりゃりゅりょわゐゑをんがぎぐげごぎゃぎゅぎょざじずぜぞじゃじゅじょだぢづでどぢゃぢゅぢょばびぶべぼびゃびゅびょぱぴぷぺぽぴゃぴゅぴょっ";
  
  NSString *katakanaOutput = @"アイウエオカキクケコキャキュキョサシスセソシャシュショタチツテトチャチュチョナニヌネノニャニュニョハヒフヘホヒャヒュヒョマミムメモミャミュミョヤユヨラリルレロリャリュリョワヰヱヲンガギグゲゴギャギュギョザジズゼゾジャジュジョダヂヅデドヂャヂュヂョバビブベボビャビュビョパピプペポピャピュピョッ";
  NSString *converted = ConvertHiraganaToKatakana(hiraganaInput);
  
  XCTAssertEqualObjects(katakanaOutput,converted);
}

@end
