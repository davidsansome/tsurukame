#import "ReviewSummaryCell.h"
#import "ReviewSummaryViewController.h"

@interface ReviewSummaryViewController () <UITableViewDataSource>

@end

@implementation ReviewSummaryViewController {
  int _incorrectReadings;
  int _incorrectMeanings;
  int _correct;
  int _currentLevel;
  NSMutableArray<ReviewItem *> *_currentLevelItemsWrong;
}

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)setItems:(NSArray<ReviewItem *> *)items {
  _items = items;
  _incorrectMeanings = 0;
  _incorrectReadings = 0;
  _correct = 0;
  _currentLevel = [_localCachingClient getUserInfo].level;
  _currentLevelItemsWrong = [NSMutableArray array];
  
  for (ReviewItem *item in items) {
    if (!item.answer.meaningWrong && !item.answer.readingWrong) {
      _correct ++;
    } else {
      if (item.answer.meaningWrong) {
        _incorrectMeanings ++;
      }
      if (item.answer.readingWrong) {
        _incorrectReadings ++;
      }
      if (item.assignment.level == _currentLevel) {
        [_currentLevelItemsWrong addObject:item];
      }
    }
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  switch (section) {
    case 0:
      return @"Summary";
    case 1:
      return [NSString stringWithFormat:@"Wrong answers (level %d)", _currentLevel];
  }
  return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  switch (section) {
    case 0:
      return 3;
    case 1:
      return _currentLevelItemsWrong.count;
  }
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *ret = nil;
  switch (indexPath.section) {
    case 0:
      ret = [tableView dequeueReusableCellWithIdentifier:@"summaryCell"];
      switch (indexPath.row) {
        case 0:
          ret.textLabel.text = @"Items answered correctly";
          ret.detailTextLabel.text = [NSString stringWithFormat:@"%d (%d%%)",
                                      _correct,
                                      (int)((double)(_correct) / _items.count * 100)];
          break;
        case 1:
          ret.textLabel.text = @"Incorrect readings";
          ret.detailTextLabel.text = [@(_incorrectReadings) stringValue];
          break;
        case 2:
          ret.textLabel.text = @"Incorrect meanings";
          ret.detailTextLabel.text = [@(_incorrectMeanings) stringValue];
          break;
      }
      break;
      
    case 1: {
      ret = [tableView dequeueReusableCellWithIdentifier:@"reviewCell"];
      ReviewItem *item = _items[indexPath.row];
      WKSubject *subject = [_dataLoader loadSubject:item.assignment.subjectId];
      [((ReviewSummaryCell *)ret) setItem:item subject:subject];
      break;
    }
  }
  return ret;
}

@end
