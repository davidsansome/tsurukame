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

#import "TKMFontLoader.h"

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

#import "UserDefaults.h"

static dispatch_once_t sOnceToken;
static NSArray<TKMFont*> *sLoadedFonts;
static NSPredicate * sEnabledPredicate;
static NSString *const kFontDirectory = @"fonts";

NSString *LoadFontFromUrl(NSURL *url) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSData *data = [fileManager contentsAtPath: [url path]];
  
  CFErrorRef error;
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
  CGFontRef font = CGFontCreateWithDataProvider(provider);
  if (! CTFontManagerRegisterGraphicsFont(font, &error)) {
    CFStringRef errorDescription = CFErrorCopyDescription(error);
    NSLog(@"Failed to load font: %@", errorDescription);
    CFRelease(errorDescription);
    CFRelease(font);
    CFRelease(provider);
    return nil;
  }
  CFStringRef fontName = CGFontCopyFullName(font);
  
  CFRelease(font);
  CFRelease(provider);
  return (__bridge NSString *) fontName;
}

void EnsureInitialized() {
  dispatch_once(&sOnceToken, ^{
    sEnabledPredicate = [NSPredicate predicateWithFormat:@"enabled == true"];
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray<NSURL*> *urls = [mainBundle URLsForResourcesWithExtension:nil subdirectory:kFontDirectory];
    
    NSMutableArray<TKMFont*> *fonts = [NSMutableArray array];
    
    NSArray<TKMFont*> *fontsFromDefaults = UserDefaults.usedFonts;
    
    for (NSURL *url in urls) {
      TKMFont *newFont = [[TKMFont alloc] init];
      newFont.fontName = LoadFontFromUrl(url);
      if (newFont.fontName == nil) {
        continue;
      }
      
      NSPredicate *fontNamePredicate = [NSPredicate predicateWithFormat: @"fontName == %@", newFont.fontName];
      NSArray<TKMFont*> *filteredArray = [fontsFromDefaults filteredArrayUsingPredicate:fontNamePredicate];
      newFont.enabled = filteredArray == nil || filteredArray.firstObject.enabled;
      
      [fonts addObject:newFont];
    }
    
    sLoadedFonts = fonts;
  });
}


@implementation TKMFontLoader

+ (NSArray<TKMFont*> *)getLoadedFonts {
  EnsureInitialized();
  return sLoadedFonts;
}

+ (NSArray<TKMFont*> *)getEnabledFonts {
  return [[TKMFontLoader getLoadedFonts] filteredArrayUsingPredicate:sEnabledPredicate];
}

+ (BOOL)font:(TKMFont*)font canRender:(NSString*)text {
  CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, 0.0, NULL);
  
  NSUInteger count = text.length;
  unichar characters[count];
  CGGlyph glyphs[count];
  [text getCharacters:characters range:NSMakeRange(0, count)];
  
  BOOL canRender = CTFontGetGlyphsForCharacters(fontRef, characters, glyphs, count);
  CFRelease(fontRef);
  
  return canRender;
}

+ (TKMFont*)getRandomFontToRender:(NSString*)text {
  NSPredicate *fontPredicate = [NSPredicate predicateWithBlock:^BOOL(TKMFont *font, NSDictionary *_) {
    return font.enabled && [TKMFontLoader font:font canRender:text];
  }];
  
  NSArray<TKMFont*> *availableFonts = [[TKMFontLoader getLoadedFonts] filteredArrayUsingPredicate:fontPredicate];
  NSUInteger random = arc4random_uniform((uint32_t)[availableFonts count]);
  return availableFonts[random];
}

+ (void) saveToUserDefaults {
  UserDefaults.usedFonts = sLoadedFonts;
}

@end

@implementation TKMFont

- (instancetype)initWithFontName:(NSString*)fontName enabled:(BOOL)enabled{
  self = [super init];
  if (self) {
    _fontName = fontName;
    _enabled = enabled;
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  NSString *fontName = (NSString*)[aDecoder decodeObjectForKey:@"fontName"];
  BOOL enabled = [aDecoder decodeBoolForKey:@"enabled"];
  
  return [self initWithFontName:fontName enabled:enabled];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:_fontName forKey:@"fontName"];
  [coder encodeBool:_enabled forKey:@"enabled"];
}

@end
