//
//  KTMKanaTest.m
//  Tests
//
//  Created by Henri on 04.10.18.
//  Copyright © 2018 David Sansome. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "../TKMKanaInput.h"
#import "../TKMKanaInput.m"

@interface StubUITextField : UITextField
@end

@implementation StubUITextField
@end

@interface StubUITextFieldDelegate : NSObject <UITextFieldDelegate>
@end

@implementation StubUITextFieldDelegate

@end

@interface TKMKanaInputTest : XCTestCase

@end

@implementation TKMKanaInputTest
static NSCharacterSet *_tsuConsonants;
static NSArray *_tsuConsonantsArray;
TKMKanaInput *_kanaInput;
UITextField *_stub;

// TODO: I don't know how memory management in objective-c works...is it ok to return a NSArray* ?
+ (NSArray*)getCharactersFromCharacterSet:(NSCharacterSet*)charset {
    NSMutableArray *array = [NSMutableArray array];
    for (int plane = 0; plane <= 16; plane++) {
        if ([charset hasMemberInPlane:plane]) {
            UTF32Char c;
            for (c = plane << 16; c < (plane+1) << 16; c++) {
                if ([charset longCharacterIsMember:c]) {
                    UTF32Char c1 = OSSwapHostToLittleInt32(c); // To make it byte-order safe
                    NSString *s = [[NSString alloc] initWithBytes:&c1 length:4 encoding:NSUTF32LittleEndianStringEncoding];
                    [array addObject:s];
                }
            }
        }
    }
    return array;
}

+ (void)setUp {
    // Put setup code here. This method is called before the invocation of all test methods in the class.
    
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
    
    _stub = [[StubUITextField alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testkReplacementsContainsOnlyValidCombinations {
    for(NSString *key1 in [kReplacements keyEnumerator]) {
        for(NSString *key2 in [kReplacements keyEnumerator]) {
            XCTAssertFalse(key1 != key2 && [key1 hasPrefix:key2]);
        }
    }
}

- (void)testShouldChangeCharactersInRange1 {
    // when the _kanaInput is disabled shouldChangeCharactersInRange should return true and the text should be unchanged
    
    NSString *text = [_stub.text copy];
    
    _kanaInput.enabled = false;
    BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(0, 0) replacementString:@""];
    
    XCTAssertTrue(returnValue);
    XCTAssertEqualObjects(text, _stub.text);
}

- (void)testShouldChangeCharactersInRange2 {
    // when the length of the Range is greater 0 shouldChangeCharactersInRange should return true and the text should be unchanged
    
    NSString *text = [_stub.text copy];
    
    BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(0, 3) replacementString:@""];
    
    XCTAssertTrue(returnValue);
    XCTAssertEqualObjects(text, _stub.text);
}

- (void)testShouldChangeCharactersInRange3 {
    // when there is a consonant and you type the same consonant it should be replaced by っ and the returnValue should be true
    
    for(NSString *consonant in _tsuConsonantsArray) {
        _stub.text = consonant;
        
        BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:consonant];
        
        XCTAssertTrue(returnValue);
        XCTAssertEqualObjects(@"っ", _stub.text);
    }
}

- (void)testShouldChangeCharactersInRange4 {
    // when there is a n or m and you type a consonant it should be replaced by ん and the returnValue should be true
    
    NSArray *kNArray = [TKMKanaInputTest getCharactersFromCharacterSet:kN];
    
    for(NSString *consonant in _tsuConsonantsArray) {
        if(![kCanFollowN characterIsMember:[consonant characterAtIndex:0]]) {
            for(NSString *nm in kNArray) {
                _stub.text = nm;
                
                BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:consonant];
                
                XCTAssertTrue(returnValue);
                XCTAssertEqualObjects(@"ん", _stub.text);
            }
        }
    }
}

- (void)testShouldChangeCharactersInRange5 {
    // when there is the start of a pattern and you type the last letter of the pattern it should be replaced by the given replacement and the returnValue should be false
    
    for(NSString *replacement in [kReplacements keyEnumerator]) {
        // this pattern is checked by another case...for this function it doesn't matter if it is in the kReplacements CharacterSet
        if([replacement isEqualToString:@"n "]) {
            continue;
        }
        
        NSString *lastReplacementCharacter = [replacement substringFromIndex:replacement.length - 1];
        
        _stub.text = [replacement substringToIndex:replacement.length - 1];
        
        BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(_stub.text.length, 0) replacementString: lastReplacementCharacter];
        XCTAssertFalse(returnValue);
        XCTAssertEqualObjects(kReplacements[replacement], _stub.text);
    }
}

- (void)testShouldChangeCharactersInRange6 {
    // when you type a uppercase consonant followed by the same consonant, it should be replaced by ッ
    
    for(NSString *consonant in _tsuConsonantsArray) {
        NSString *uppercaseConsonant = [consonant uppercaseString];
        _stub.text = uppercaseConsonant;
        
        BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:uppercaseConsonant];
        
        XCTAssertTrue(returnValue);
        XCTAssertEqual(@"ッ", _stub.text);
    }
}

- (void)testShouldChangeCharactersInRange7 {
    // when there is a N or M and you type a consonant it should be replaced by ン and the returnValue should be true
    
    NSArray *kNArray = [TKMKanaInputTest getCharactersFromCharacterSet:kN];
    
    for(NSString *consonant in _tsuConsonantsArray) {
        if(![kCanFollowN characterIsMember:[consonant characterAtIndex:0]]) {
            for(NSString *nm in kNArray) {
                _stub.text = [nm uppercaseString];
                
                BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(1, 0) replacementString:consonant];
                
                XCTAssertTrue(returnValue);
                NSLog(@"%@", _stub.text);
                XCTAssertEqualObjects(@"ン", _stub.text);
            }
        }
    }
}

- (void)testShouldChangeCharactersInRange8 {
    // when there is the start of a pattern, the first letter of the patten is uppercase and you type the last letter of the pattern it should be replaced by the given replacement in katakana and the returnValue should be false
    
    for(NSString *replacement in [kReplacements keyEnumerator]) {
        // this pattern is checked by another case...for this function it doesn't matter if it is in the kReplacements CharacterSet
        if([replacement isEqualToString:@"n "]) {
            continue;
        }
        
        NSString *lastReplacementCharacter = [replacement substringFromIndex:replacement.length - 1];
        
        
        _stub.text = [[replacement substringToIndex:replacement.length - 1] capitalizedString];
        
        BOOL returnValue = [_kanaInput textField:_stub shouldChangeCharactersInRange:NSMakeRange(_stub.text.length, 0) replacementString: lastReplacementCharacter];
        XCTAssertFalse(returnValue);
        XCTAssertEqualObjects(kReplacements[replacement], _stub.text);
    }
}

@end
