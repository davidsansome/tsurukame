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

#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>

#import "Settings.h"

NSString *const kTKMFontPreviewText =
    @"色は匂へど散りぬるを我が世誰ぞ常ならん有為の奥山今日越えて浅き夢見じ酔ひもせず";

struct FontDefinition {
  NSString *fontName;
  NSString *fileName;
  NSString *displayName;
  int64_t sizeBytes;
};
static const FontDefinition kFontDefinitions[] = {
    {@"ArmedBanana", @"armed-banana.ttf", @"Armed Banana", 3298116},
    {@"darts font", @"darts-font.woff", @"Darts", 1349440},
    {@"Hosofuwafont", @"hoso-fuwa.ttf", @"Hoso Fuwa", 5910760},
    {@"nagayama_kai", @"nagayama-kai.otf", @"Nagayama Kai calligraphy", 15576732},
    {@"santyoume-font", @"san-chou-me.ttf", @"San Chou Me", 4428896},
};

static BOOL LoadFont(NSString *path) {
  NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
  if (!data) {
    return NO;
  }

  CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
  CGFontRef font = CGFontCreateWithDataProvider(provider);
  BOOL ret = CTFontManagerRegisterGraphicsFont(font, nil);
  CFRelease(font);
  CFRelease(provider);
  return ret;
}

BOOL TKMFontCanRenderText(NSString *fontName, NSString *text) {
  CTFontRef fontRef = CTFontCreateWithName((CFStringRef)fontName, 0.0, NULL);
  if (!fontRef) {
    return NO;
  }

  NSUInteger count = text.length;
  unichar characters[count];
  CGGlyph glyphs[count];
  [text getCharacters:characters range:NSMakeRange(0, count)];

  BOOL canRender = CTFontGetGlyphsForCharacters(fontRef, characters, glyphs, count);
  if (canRender) {
    // CTFontGetGlyphsForCharacters can return a glyph that has no path, so will be invisible when
    // drawn.  Check every glyph has a path as well.
    for (int i = 0; i < count; ++i) {
      CGPathRef path = CTFontCreatePathForGlyph(fontRef, glyphs[i], NULL);
      if (!path) {
        return NO;
      }
      CGPathRelease(path);
    }
  }

  CFRelease(fontRef);

  return canRender;
}

@interface TKMFont ()

- (instancetype)initFromDefinition:(const FontDefinition &)definition;

@end

@implementation TKMFontLoader

+ (NSString *)cacheDirectoryPath {
  NSArray<NSString *> *paths =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return [NSString stringWithFormat:@"%@/fonts", paths.firstObject];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    NSMutableArray<TKMFont *> *allFonts = [NSMutableArray array];
    for (const FontDefinition &definition : kFontDefinitions) {
      [allFonts addObject:[[TKMFont alloc] initFromDefinition:definition]];
    }
    _allFonts = allFonts;
  }
  return self;
}

- (nullable TKMFont *)fontByName:(NSString *)fileName {
  for (TKMFont *font in _allFonts) {
    if ([font.fileName isEqual:fileName]) {
      return font;
    }
  }
  return nil;
}

@end

@implementation TKMFont {
  FontDefinition _definition;
}

- (instancetype)initFromDefinition:(const FontDefinition &)definition {
  self = [super init];
  if (self) {
    _definition = definition;
    [self reload];
  }
  return self;
}

- (NSString *)displayName {
  return _definition.displayName;
}

- (NSString *)fileName {
  return _definition.fileName;
}

- (NSString *)fontName {
  return _definition.fontName;
}

- (int64_t)sizeBytes {
  return _definition.sizeBytes;
}

- (void)reload {
  if (_available) {
    return;
  }
  if ([UIFont fontNamesForFamilyName:self.fontName].count) {
    _available = YES;
    return;
  }

  // Try to load a built-in font first.
  NSString *resource = [NSString stringWithFormat:@"fonts/%@", self.fileName];
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *path = [mainBundle pathForResource:resource ofType:nil];
  if (LoadFont(path)) {
    _available = YES;
    return;
  }

  // Try to load the downloaded font.
  path = [NSString stringWithFormat:@"%@/%@", [TKMFontLoader cacheDirectoryPath], self.fileName];
  NSLog(@"Loading font %@", path);
  if (LoadFont(path)) {
    _available = YES;
    return;
  }
}

- (void)didDelete {
  _available = NO;
}

- (UIImage *)loadScreenshot {
  return [UIImage imageNamed:[NSString stringWithFormat:@"%@", self.fontName]];
}

@end
