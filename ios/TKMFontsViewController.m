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

#import "TKMFontsViewController.h"
#import "Tables/TKMBasicModelItem.h"
#import "Tables/TKMDownloadModelItem.h"
#import "Tables/TKMTableModel.h"
#import "Tsurukame-Swift.h"

static NSString *const kURLPattern = @"https://tsurukame.app/fonts/%@";

@interface TKMFontsViewController ()

@end

@implementation TKMFontsViewController {
  TKMServices *_services;
  NSFileManager *_fileManager;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _fileManager = [[NSFileManager alloc] init];
  }
  return self;
}

- (void)setupWithServices:(TKMServices *)services {
  _services = services;
}

- (void)populateModel:(TKMMutableTableModel *)model {
  [model addSection:@""
             footer:
                 @"Choose the fonts you want to use while doing reviews. "
                  "Tsurukame will pick a random font from the ones you've selected for every new "
                  "word."];

  [model addSection];
  for (TKMFont *font in _services.fontLoader.allFonts) {
    TKMDownloadModelItem *item = [[TKMDownloadModelItem alloc] initWithFilename:font.fileName
                                                                          title:font.displayName
                                                                       delegate:self];
    item.totalSizeBytes = font.sizeBytes;

    NSURLSessionDownloadTask *download = [self activeDownloadFor:font.fileName];
    if (download) {
      item.previewImage = [font loadScreenshot];
      item.state = TKMDownloadModelItemDownloading;
    } else if (font.available) {
      item.previewText = TKMFont.fontPreviewText;
      item.previewFontName = font.fontName;
      if ([Settings.selectedFonts containsObject:font.fileName]) {
        item.state = TKMDownloadModelItemInstalledSelected;
      } else {
        item.state = TKMDownloadModelItemInstalledNotSelected;
      }
    } else {
      item.previewImage = [font loadScreenshot];
      item.state = TKMDownloadModelItemNotInstalled;
    }
    [model addItem:item];
  }

  if ([_fileManager fileExistsAtPath:[TKMFontLoader cacheDirectoryPath]]) {
    [model addSection];
    TKMBasicModelItem *deleteItem =
        [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                           title:@"Delete all downloaded fonts"
                                        subtitle:nil
                                   accessoryType:UITableViewCellAccessoryNone
                                          target:self
                                          action:@selector(didTapDeleteAllFonts:)];
    deleteItem.textColor = [UIColor systemRedColor];
    [model addItem:deleteItem];
  }
}

- (NSURL *)urlForFilename:(NSString *)filename {
  return [NSURL URLWithString:[NSString stringWithFormat:kURLPattern, filename]];
}

- (void)didFinishDownloadFor:(NSString *)filename atURL:(NSURL *)location {
  // Create the cache directory.
  NSError *error;
  [_fileManager createDirectoryAtPath:[TKMFontLoader cacheDirectoryPath]
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
  if (error) {
    [self reportErrorOnMainThread:filename
                            title:@"Error creating directory"
                          message:error.localizedDescription];
    return;
  }

  // Move the downloaded file to the cache directory.
  NSURL *destination = [NSURL
      fileURLWithPath:[NSString
                          stringWithFormat:@"%@/%@", [TKMFontLoader cacheDirectoryPath], filename]];
  [_fileManager moveItemAtURL:location toURL:destination error:&error];
  if (error) {
    [self reportErrorOnMainThread:filename
                            title:@"Error moving downloaded file"
                          message:error.localizedDescription];
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [[_services.fontLoader fontWithName:filename] reload];
    [self toggleItem:filename selected:YES];
    [self markDownloadComplete:filename];
  });
}

- (void)toggleItem:(NSString *)filename selected:(BOOL)selected {
  NSMutableSet<NSString *> *selectedFonts = [NSMutableSet setWithSet:Settings.selectedFonts];
  if (selected) {
    [selectedFonts addObject:filename];
  } else {
    [selectedFonts removeObject:filename];
  }
  Settings.selectedFonts = selectedFonts;
}

- (void)didTapDeleteAllFonts:(id)sender {
  __weak TKMFontsViewController *weakSelf = self;
  UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Delete all downloaded fonts"
                                                             message:@"Are you sure?"
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [c addAction:[UIAlertAction actionWithTitle:@"Delete"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        [weakSelf deleteAllFonts];
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)deleteAllFonts {
  NSError *error;
  if (![_fileManager removeItemAtPath:[TKMFontLoader cacheDirectoryPath] error:&error]) {
    [self reportErrorOnMainThread:nil
                            title:@"Error deleting files"
                          message:error.localizedDescription];
  } else {
    Settings.selectedFonts = [NSSet set];
    for (TKMFont *font in _services.fontLoader.allFonts) {
      [font didDelete];
    }
    [self rerender];
  }
}

@end
