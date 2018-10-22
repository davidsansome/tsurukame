//
//  TKMFontModelItem.h
//  Tsurukame
//
//  Created by Henri on 13.10.18.
//  Copyright © 2018 David Sansome. All rights reserved.
//

#import "TKMModelItem.h"
#import "../TKMFontLoader.h"
#import "../TKMFontDelegate.h"


NS_ASSUME_NONNULL_BEGIN

@interface TKMFontModelView : TKMModelCell

@end


@interface TKMFontModelItem : NSObject <TKMModelItem>

- (instancetype)initWithFont:(TKMFont *)font delegate:(id<TKMFontDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)setSelected:(BOOL)selected;

@property(nonatomic, copy) TKMFont *font;
@property(nonatomic, weak) id<TKMFontDelegate> delegate;

@end


NS_ASSUME_NONNULL_END
