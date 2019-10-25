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

#import "TKMDownloadModelItem.h"

#import "Style.h"

static NSString *FriendlySize(int64_t bytes) {
  if (bytes < 1000) {
    return [NSString stringWithFormat:@"%lld bytes", bytes];
  } else if (bytes < 1000 * 1000) {
    return [NSString stringWithFormat:@"%lld kB", bytes / 1000];
  } else {
    return [NSString stringWithFormat:@"%lld MB", bytes / (1000 * 1000)];
  }
}

@interface TKMDownloadModelView ()
@property(nonatomic, weak) IBOutlet UIView *previewContainer;
@property(nonatomic, weak) IBOutlet UILabel *preview;
@property(nonatomic, weak) IBOutlet UIImageView *previewImage;
@property(nonatomic, weak) IBOutlet UILabel *title;
@property(nonatomic, weak) IBOutlet UILabel *subtitle;
@property(nonatomic, weak) IBOutlet UIImageView *image;
@end

@implementation TKMDownloadModelItem

- (instancetype)initWithFilename:(NSString *)filename
                           title:(NSString *)title
                        delegate:(id<TKMDownloadModelDelegate>)delegate {
  self = [super init];
  if (self) {
    _filename = filename;
    _title = title;
    _delegate = delegate;
  }
  return self;
}

- (NSString *)cellNibName {
  return @"TKMDownloadModelItem";
}

@end

@implementation TKMDownloadModelView

- (void)updateWithItem:(TKMDownloadModelItem *)item {
  [super updateWithItem:item];

  _title.text = item.title;

  switch (item.state) {
    case TKMDownloadModelItemNotInstalled:
      _subtitle.text =
          [NSString stringWithFormat:@"not installed - %@", FriendlySize(item.totalSizeBytes)];
      [_image setImage:[UIImage imageNamed:@"baseline_cloud_download_black_24pt"]];
      [_image setTintColor:TKMDefaultTintColor()];
      break;
    case TKMDownloadModelItemDownloading:
    case TKMDownloadModelItemInstalling:
      [self updateProgress];
      [_image setImage:[UIImage imageNamed:@"baseline_cancel_black_24pt"]];
      [_image setTintColor:[UIColor lightGrayColor]];
      break;
    case TKMDownloadModelItemInstalledSelected:
      _subtitle.text = nil;
      [_image setImage:[UIImage imageNamed:@"tick"]];
      [_image setTintColor:TKMDefaultTintColor()];
      break;
    case TKMDownloadModelItemInstalledNotSelected:
      _subtitle.text = nil;
      [_image setImage:[UIImage imageNamed:@"tick"]];
      [_image setTintColor:[UIColor lightGrayColor]];
      break;
  }

  _preview.hidden = YES;
  _previewImage.hidden = YES;
  if (item.previewText.length) {
    _preview.hidden = NO;
    _preview.text = item.previewText;
    _preview.font = [UIFont fontWithName:item.previewFontName size:26.f];
    _preview.accessibilityLabel = item.previewAccessibilityLabel;
  } else if (item.previewImage) {
    _previewImage.hidden = NO;
    _previewImage.image = item.previewImage;
  }
  _previewContainer.hidden = _preview.hidden && _previewImage.hidden;
}

- (void)updateProgress {
  TKMDownloadModelItem *item = (TKMDownloadModelItem *)self.item;
  switch (item.state) {
    case TKMDownloadModelItemDownloading:
      _subtitle.text =
          [NSString stringWithFormat:@"downloading %lld%%",
                                     item.downloadingProgressBytes * 100 / item.totalSizeBytes];
      break;
    case TKMDownloadModelItemInstalling:
      _subtitle.text =
          [NSString stringWithFormat:@"installing %d%%", (int)(item.installingProgress * 100)];
      break;
    default:
      break;
  }
}

- (void)didSelectCell {
  TKMDownloadModelItem *item = (TKMDownloadModelItem *)self.item;
  [item.delegate didTapDownloadItem:item];
}

@end
