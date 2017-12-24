#import "ReviewSummaryCell.h"
#import "ReviewSummaryViewController.h"
#import "SubjectDetailsViewController.h"

@interface ReviewSummaryViewController () <UITableViewDataSource>

@end

@implementation ReviewSummaryViewController {
  int _correct;
  int _currentLevel;
  NSArray<NSNumber *> *_incorrectItemLevels;
  NSArray<NSArray<ReviewItem *> *> *_incorrectItems;
}

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"subjectDetails"]) {
    ReviewSummaryCell *cell = (ReviewSummaryCell *)sender;
    SubjectDetailsViewController *vc = (SubjectDetailsViewController *)segue.destinationViewController;
    vc.dataLoader = _dataLoader;
    vc.localCachingClient = _localCachingClient;
    vc.subject = cell.subject;
  }
}

- (IBAction)doneClicked:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)setItems:(NSArray<ReviewItem *> *)items {
  _items = items;
  _correct = 0;
  _currentLevel = [_localCachingClient getUserInfo].level;
  
  NSMutableDictionary<NSNumber *, NSMutableArray<ReviewItem *> *> *incorrectItemsByLevel =
      [NSMutableDictionary dictionary];
  
  for (ReviewItem *item in items) {
    if (!item.answer.meaningWrong && !item.answer.readingWrong) {
      _correct ++;
      continue;
    }
    if (incorrectItemsByLevel[@(item.assignment.level)] == nil) {
      incorrectItemsByLevel[@(item.assignment.level)] = [NSMutableArray array];
    }
    [incorrectItemsByLevel[@(item.assignment.level)] addObject:item];
  }
  
  NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(compare:)];
  _incorrectItemLevels = [[incorrectItemsByLevel allKeys] sortedArrayUsingDescriptors:@[sortDescriptor]];
  NSMutableArray<NSArray<ReviewItem *> *> *incorrectItems =
      [NSMutableArray arrayWithCapacity:_incorrectItemLevels.count];
  for (NSNumber *level in _incorrectItemLevels) {
    [incorrectItems addObject:incorrectItemsByLevel[level]];
  }
  _incorrectItems = incorrectItems;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1 + _incorrectItemLevels.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    return @"Summary";
  }
  NSNumber *level = _incorrectItemLevels[section - 1];
  if ([level intValue] == _currentLevel) {
    return [NSString stringWithFormat:@"Current level (%d)", _currentLevel];
  }
  return [NSString stringWithFormat:@"Level %d", [level intValue]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return 1;
  }
  return _incorrectItems[section - 1].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *ret = nil;
  if (indexPath.section == 0) {
    ret = [tableView dequeueReusableCellWithIdentifier:@"summaryCell"];
    switch (indexPath.row) {
      case 0:
        ret.textLabel.text = @"Correct answers";
        ret.detailTextLabel.text = [NSString stringWithFormat:@"%d%% (%d/%lu)",
                                    (int)((double)(_correct) / _items.count * 100),
                                    _correct,
                                    (unsigned long)_items.count];
        break;
    }
  } else {
    ret = [tableView dequeueReusableCellWithIdentifier:@"reviewCell"];
    ReviewItem *item = _incorrectItems[indexPath.section - 1][indexPath.row];
    WKSubject *subject = [_dataLoader loadSubject:item.assignment.subjectId];
    ReviewSummaryCell *cell = (ReviewSummaryCell *)ret;
    cell.item = item;
    cell.subject = subject;
  }
  return ret;
}

@end
