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

#import "UserDefaults.h"

struct FontDefinition {
  NSString *fontName;
  NSString *fileName;
  NSString *displayName;
  int64_t sizeBytes;
};
static const FontDefinition kFontDefinitions[] = {
  {@"ArmedBanana", @"armedbanana.ttf", @"Armed Banana", 3298116},
  {@"darts font", @"dartsfont.woff", @"Darts", 1349440},
  {@"FC-Flower", @"fc_fl.ttf", @"FC Flower handwriting", 659800},
  {@"Hosofuwafont", @"Hosohuwafont.ttf", @"Hoso Fuwa", 5910760},
  {@"nagayama_kai", @"nagayama_kai08.otf", @"Nagayama Kai calligraphy", 15576732},
  {@"santyoume-font", @"KUDOU.TTF", @"San Chou Me", 4428896},
};

BOOL LoadFont(NSString *path) {
  NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
  
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
  CGFontRef font = CGFontCreateWithDataProvider(provider);
  BOOL ret = CTFontManagerRegisterGraphicsFont(font, nil);
  CFRelease(font);
  CFRelease(provider);
  return ret;
}


@interface TKMFont ()

- (instancetype)initFromDefinition:(const FontDefinition &)definition;

@end


@implementation TKMFontLoader

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
  
  // Try to load a built-in font first.
  NSString *resource = [NSString stringWithFormat:@"fonts/%@", _definition.fileName];
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *path = [mainBundle pathForResource:resource ofType:nil];
  if (LoadFont(path)) {
    _available = YES;
    return;
  }
  
  // Try to load the downloaded font.
  // TODO: plz.
}

@end
