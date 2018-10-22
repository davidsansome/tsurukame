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
static NSArray *loadedFonts;

void EnsureInitialized() {
  dispatch_once(&sOnceToken, ^{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray *urls = [mainBundle URLsForResourcesWithExtension:nil subdirectory:@"Ressources/fonts"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *fonts = [[NSMutableArray alloc] init];
    
    NSArray *fontsFromDefaults = UserDefaults.usedFonts;
    
    for (NSURL *url in urls) {
      NSData *data = [fileManager contentsAtPath: [url path]];
      
      CFErrorRef error;
      CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
      CGFontRef font = CGFontCreateWithDataProvider(provider);
      if (! CTFontManagerRegisterGraphicsFont(font, &error)) {
        CFStringRef errorDescription = CFErrorCopyDescription(error);
        NSLog(@"Failed to load font: %@", errorDescription);
        CFRelease(errorDescription);
      }
      CFStringRef fontName = CGFontCopyFullName(font);
      
      TKMFont *newFont = [[TKMFont alloc] init];
      newFont.fontName = (__bridge NSString *) fontName;
      
      NSPredicate *fontNamePredicate = [NSPredicate predicateWithFormat: @"fontName == %@", newFont.fontName];
      NSArray *filteredArray = [fontsFromDefaults filteredArrayUsingPredicate:fontNamePredicate];
      newFont.enabled = [filteredArray count] >= 1 ? [[filteredArray objectAtIndex:0] enabled] : false;
      
      [fonts addObject:newFont];
      
      CFRelease(font);
      CFRelease(provider);
    }
    
    loadedFonts = fonts;
  });
}


@implementation TKMFontLoader

+ (NSArray *)getLoadedFonts {
  EnsureInitialized();
  return loadedFonts;
}

+ (BOOL) font:(TKMFont*)font canRender:(NSString*)text {
  CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, 0.0, NULL);
  
  NSUInteger count = text.length;
  unichar characters[count];
  CGGlyph glyphs[count];
  [text getCharacters:characters range:NSMakeRange(0, count)];
  
  // TODO: find better solution for this
  return CTFontGetGlyphsForCharacters(fontRef, characters, glyphs, count);
}

+ (NSString*) getRandomFontToRender:(NSString*)text {
  NSPredicate *fontPredicate = [NSPredicate predicateWithBlock:^BOOL(TKMFont *font, NSDictionary *_) {
    return font.enabled && [TKMFontLoader font:font canRender:text];
  }];
  
  NSArray *availableFonts = [[TKMFontLoader getLoadedFonts] filteredArrayUsingPredicate:fontPredicate];
  NSUInteger random = arc4random_uniform((uint32_t)[availableFonts count]);
  return [[availableFonts objectAtIndex:random] fontName];
}

+ (void) saveToUserDefaults {
  UserDefaults.usedFonts = loadedFonts;
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
