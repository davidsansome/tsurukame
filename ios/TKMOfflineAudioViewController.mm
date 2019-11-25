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

#import "TKMOfflineAudioViewController.h"

#import "Settings.h"
#import "TKMAudio.h"
#import "Tables/TKMBasicModelItem.h"
#import "Tables/TKMDownloadModelItem.h"
#import "Tables/TKMTableModel.h"

#import <Light-Untar-umbrella.h>
#import <compression.h>
#import <memory>

static NSString *const kURLPattern = @"https://tsurukame.app/audio/%@";

struct AvailablePackage {
  NSString *filename;
  NSString *title;
  int64_t sizeBytes;
};

static const AvailablePackage kAvailablePackages[] = {
    {@"a-levels-1-10.tar.lzfse", @"Levels 1-10", 20929198},
    {@"a-levels-11-20.tar.lzfse", @"Levels 11-20", 26205096},
    {@"a-levels-21-30.tar.lzfse", @"Levels 21-30", 25755242},
    {@"a-levels-31-40.tar.lzfse", @"Levels 31-40", 23207068},
    {@"a-levels-41-50.tar.lzfse", @"Levels 41-50", 20776153},
    {@"a-levels-51-60.tar.lzfse", @"Levels 51-60", 18827575},
};

static NSData *DecompressLZFSE(NSData *compressedData) {
  if (!compressedData.length) {
    return nil;
  }

  // Assume a compression ratio of 1.25.
  size_t bufferSize = compressedData.length * 1.25;

  while (true) {
    NSLog(@"Decompressing data of size %lu into buffer of size %zu",
          (unsigned long)compressedData.length, bufferSize);

    uint8_t *buffer = (uint8_t *)malloc(bufferSize);
    size_t decodedSize =
        compression_decode_buffer(buffer, bufferSize, (const uint8_t *)compressedData.bytes,
                                  compressedData.length, nil, COMPRESSION_LZFSE);
    if (decodedSize == 0) {
      NSLog(@"Decompression error");
      free(buffer);
      return nil;
    }
    if (decodedSize == bufferSize) {
      NSLog(@"Buffer wasn't big enough - trying again");
      // The buffer wasn't big enough - try again.
      free(buffer);
      bufferSize *= 1.25;
      continue;
    }
    NSLog(@"Decompressed %lu bytes", decodedSize);
    return [NSData dataWithBytesNoCopy:buffer length:decodedSize];
  }
}

@interface TKMOfflineAudioViewController ()

@end

@implementation TKMOfflineAudioViewController {
  NSFileManager *_fileManager;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _fileManager = [[NSFileManager alloc] init];
  }
  return self;
}

- (void)populateModel:(TKMMutableTableModel *)model {
  [model addSection:@""
             footer:
                 @"Download audio to your phone so it plays without delay and "
                  "is available when you're not connected to the internet."];

  for (const AvailablePackage &package : kAvailablePackages) {
    TKMDownloadModelItem *item = [[TKMDownloadModelItem alloc] initWithFilename:package.filename
                                                                          title:package.title
                                                                       delegate:self];
    item.totalSizeBytes = package.sizeBytes;

    NSURLSessionDownloadTask *download = [self activeDownloadFor:package.filename];
    if (download) {
      item.downloadingProgressBytes = download.countOfBytesReceived;
      item.state = TKMDownloadModelItemDownloading;
    } else if ([Settings.installedAudioPackages containsObject:package.filename]) {
      item.state = TKMDownloadModelItemInstalledSelected;
    } else {
      item.state = TKMDownloadModelItemNotInstalled;
    }
    [model addItem:item];
  }

  if ([_fileManager fileExistsAtPath:[TKMAudio cacheDirectoryPath]]) {
    [model addSection];
    TKMBasicModelItem *deleteItem =
        [[TKMBasicModelItem alloc] initWithStyle:UITableViewCellStyleDefault
                                           title:@"Delete all offline audio"
                                        subtitle:nil
                                   accessoryType:UITableViewCellAccessoryNone
                                          target:self
                                          action:@selector(didTapDeleteAllAudio:)];
    deleteItem.textColor = [UIColor systemRedColor];
    [model addItem:deleteItem];
  }
}

- (NSURL *)urlForFilename:(NSString *)filename {
  return [NSURL URLWithString:[NSString stringWithFormat:kURLPattern, filename]];
}

- (void)didFinishDownloadFor:(NSString *)filename atURL:(NSURL *)location {
  NSData *lzfseData = [NSData dataWithContentsOfURL:location];
  if (!lzfseData) {
    [self reportErrorOnMainThread:filename
                            title:@"Error reading data"
                          message:[self urlForFilename:filename].absoluteString];
    return;
  }

  NSData *tarData = DecompressLZFSE(lzfseData);
  if (!tarData) {
    [self reportErrorOnMainThread:filename
                            title:@"Error decompressing data"
                          message:[self urlForFilename:filename].absoluteString];
    return;
  }

  auto extractProgress = ^(float progress) {
    [self updateProgressOnMainThread:filename
                         updateBlock:^(TKMDownloadModelItem *item) {
                           item.state = TKMDownloadModelItemInstalling;
                           item.installingProgress = progress;
                         }];
  };

  NSError *error;
  [_fileManager createFilesAndDirectoriesAtPath:[TKMAudio cacheDirectoryPath]
                                    withTarData:tarData
                                          error:&error
                                       progress:extractProgress];

  if (error) {
    [self reportErrorOnMainThread:filename
                            title:@"Error extracting data"
                          message:[self urlForFilename:filename].absoluteString];
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableSet<NSString *> *installedPackages =
        [NSMutableSet setWithSet:Settings.installedAudioPackages];
    [installedPackages addObject:filename];
    Settings.installedAudioPackages = installedPackages;

    [self markDownloadComplete:filename];
  });
}

- (void)toggleItem:(NSString *)filename selected:(BOOL)selected {
  return;
}

- (void)didTapDeleteAllAudio:(id)sender {
  __weak TKMOfflineAudioViewController *weakSelf = self;
  UIAlertController *c = [UIAlertController alertControllerWithTitle:@"Delete all offline audio"
                                                             message:@"Are you sure?"
                                                      preferredStyle:UIAlertControllerStyleAlert];
  [c addAction:[UIAlertAction actionWithTitle:@"Delete"
                                        style:UIAlertActionStyleDestructive
                                      handler:^(UIAlertAction *_Nonnull action) {
                                        [weakSelf deleteAllAudio];
                                      }]];
  [c addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                        style:UIAlertActionStyleCancel
                                      handler:nil]];
  [self presentViewController:c animated:YES completion:nil];
}

- (void)deleteAllAudio {
  NSError *error;
  if (![_fileManager removeItemAtPath:[TKMAudio cacheDirectoryPath] error:&error]) {
    [self reportErrorOnMainThread:nil
                            title:@"Error deleting files"
                          message:error.localizedDescription];
  } else {
    Settings.installedAudioPackages = [NSSet set];
    [self rerender];
  }
}

@end
