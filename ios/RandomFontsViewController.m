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

@interface RandomFontsViewController () <TKMFontDelegate>

@end

@implementation RandomFontsViewController {
  TKMTableModel *_model;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSArray *fontsArray = [TKMFontLoader getLoadedFonts];
  
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView: self.tableView];
  
  [fontsArray enumerateObjectsUsingBlock:^(TKMFont *font, NSUInteger index, BOOL *stop) {
    TKMFontModelItem *item = [[TKMFontModelItem alloc] initWithFont:font delegate:self];
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

- (void)didTapFont:(TKMFont *)font {
  //[TKMFontLoader saveToUserDefaults];
}

#pragma mark - Table view data source
/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FontShowcaseCell" forIndexPath:indexPath];
  
  NSUInteger index = [indexPath indexAtPosition: 1];
  
  TKMFont *font = [fontsArray objectAtIndex: index];
  
  cell.textLabel.text = font.fontName;
  
  return cell;
}
 */

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
