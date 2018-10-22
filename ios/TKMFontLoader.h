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

#ifndef Header_h
#define Header_h

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

@interface TKMFontLoader : NSObject

+ (NSArray*) getLoadedFonts;
+ (NSString*) getRandomFontToRender:(NSString*)text;
+ (void) saveToUserDefaults;

@end

@interface TKMFont : NSObject <NSCoding>
  @property(strong) NSString *fontName;
  @property BOOL enabled;


@end

#endif /* Header_h */
