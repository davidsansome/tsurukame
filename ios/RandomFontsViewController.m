//
//  RandomFontsViewController.m
//  Tsurukame
//
//  Created by Henri on 13.10.18.
//  Copyright © 2018 David Sansome. All rights reserved.
//

#import "RandomFontsViewController.h"
#import "TKMFontLoader.h"
#import "Tables/TKMTableModel.h"
#import "Tables/TKMFontModelItem.h"
#import "TKMFontDelegate.h"
#import "UserDefaults.h"

@interface RandomFontsViewController ()

@end

@implementation RandomFontsViewController {
  TKMTableModel *_model;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSArray *fontsArray = [TKMFontLoader getLoadedFonts];
  
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView: self.tableView];
  
  [fontsArray enumerateObjectsUsingBlock:^(TKMFont *font, NSUInteger index, BOOL *stop) {
    TKMFontModelItem *item = [[TKMFontModelItem alloc] initWithFont:font];
    [model addItem:item];
    
    if (font.enabled) {
      NSLog(@"selecting font %@", font.fontName);
      NSIndexPath *selectedIndex = [NSIndexPath indexPathForRow:index inSection:0];
      [self.tableView selectRowAtIndexPath: selectedIndex animated:NO scrollPosition: UITableViewScrollPositionNone];
    }
  }];
  
  _model = model;
}

-(void)viewWillDisappear:(BOOL)animated {
  [TKMFontLoader saveToUserDefaults];
}

@end
