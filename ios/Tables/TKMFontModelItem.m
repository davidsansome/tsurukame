//
//  TKMFontModelItem.m
//  Tsurukame
//
//  Created by Henri on 13.10.18.
//  Copyright © 2018 David Sansome. All rights reserved.
//

#import "TKMFontModelItem.h"

@interface TKMFontModelView ()

@property (weak, nonatomic) IBOutlet UILabel *fontNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *fontPreviewLabel;

@end

@implementation TKMFontModelView

- (void)updateWithItem:(TKMFontModelItem *)item {
  [super updateWithItem:item];
  
  _fontNameLabel.text = item.font.fontName;
  NSUInteger oldSize = _fontPreviewLabel.font.pointSize;
  _fontPreviewLabel.font = [UIFont fontWithName:item.font.fontName size:oldSize];
  _fontPreviewLabel.text = @"あいうえお\n漢字 字体";
}

- (void)awakeFromNib {
  [super awakeFromNib];
  // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
  [(TKMFontModelItem*)self.item setSelected:selected];
  self.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

@end

@implementation TKMFontModelItem

- (instancetype)initWithFont:(TKMFont *)font {
  self = [super init];
  if (self) {
    _font = font;
  }
  return self;
}

- (void)setSelected:(BOOL)selected {
  _font.enabled = selected;
}

- (NSString *)cellNibName {
  return @"TKMFontModelItem";
}

@end
