//
//  MainViewController.m
//  wk
//
//  Created by David Sansome on 22/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "MainViewController.h"

static NSString *kTableCellIdentifier = @"SimpleTableCell";

@interface MainViewController ()

@property (weak, nonatomic) IBOutlet UITableView *table;

@end

@implementation MainViewController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTableCellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:kTableCellIdentifier];
  }
  
  switch (indexPath.row) {
    case 0:
      cell.textLabel.text = @"Lessons";
      break;
      
    case 1:
      cell.textLabel.text = @"Reviews";
      break;
  }
  return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
  return 2;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {
  return @"Currently Available";
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  return nil;
}

@end
