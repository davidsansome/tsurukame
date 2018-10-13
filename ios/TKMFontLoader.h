//
//  Header.h
//  Tsurukame
//
//  Created by Henri on 13.10.18.
//  Copyright © 2018 David Sansome. All rights reserved.
//

#ifndef Header_h
#define Header_h

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

@interface TKMFontLoader : NSObject

+ (NSArray*) getLoadedFonts;
+ (NSArray*) getFontsThatRender:(NSString*)text;

@end

@interface TKMFont : NSObject
  @property(strong) NSString *fontName;
  @property BOOL enabled;


@end

#endif /* Header_h */
