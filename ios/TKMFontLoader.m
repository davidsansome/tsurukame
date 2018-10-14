//
//  TKMFontLoader.m
//  Tsurukame
//
//  Created by Henri on 13.10.18.
//  Copyright © 2018 David Sansome. All rights reserved.
//

#import "TKMFontLoader.h"

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

static dispatch_once_t sOnceToken;
static NSArray *loadedFonts;

void EnsureInitialized() {
  dispatch_once(&sOnceToken, ^{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray *urls = [mainBundle URLsForResourcesWithExtension:nil subdirectory:@"Resources/fonts"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSMutableArray *fonts = [[NSMutableArray alloc] init];
    
    for (NSURL *url in urls) {
      NSLog(@"Loading Data from: %@", [url path]);
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
      NSLog(@"Loaded Font: %@", fontName);
      
      TKMFont *newFont = [[TKMFont alloc] init];
      newFont.enabled = true;
      newFont.fontName = (__bridge NSString *) fontName;
      
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


+ (NSArray*) getFontsThatRender:(NSString*)text {
  EnsureInitialized();
  NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL (TKMFont *font, NSDictionary *_){
    CTFontRef fontRef = CTFontCreateWithName((CFStringRef)font.fontName, 0.0, NULL);
    
    NSUInteger count = text.length;
    unichar characters[count];
    CGGlyph glyphs[count];
    [text getCharacters:characters range:NSMakeRange(0, count)];
    
    return CTFontGetGlyphsForCharacters(fontRef, characters, glyphs, count);
  }];
  
  return [loadedFonts filteredArrayUsingPredicate:predicate];
}

@end

@implementation TKMFont

@end
