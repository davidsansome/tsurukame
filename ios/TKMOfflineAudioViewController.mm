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

#import "UserDefaults.h"
#import "Tables/TKMDownloadModelItem.h"
#import "Tables/TKMTableModel.h"
#import "TKMAudio.h"
#import "third_party/Light-Untar/NSFileManager+Tar.h"

#import <compression.h>
#import <memory>

static NSString *const kURLPattern = @"https://tsurukame.app/audio/%@";

struct AvailablePackage {
  NSString *filename;
  NSString *title;
  int64_t sizeBytes;
};
static const AvailablePackage kAvailablePackages[] = {
  {@"levels-1-10.tar.lzfse", @"Levels 1-10", 15788944},
  {@"levels-11-20.tar.lzfse", @"Levels 11-20", 25544078},
  {@"levels-21-30.tar.lzfse", @"Levels 21-30", 26003280},
  {@"levels-31-40.tar.lzfse", @"Levels 31-40", 23445692},
  {@"levels-41-50.tar.lzfse", @"Levels 41-50", 23461014},
  {@"levels-51-60.tar.lzfse", @"Levels 51-60", 30460353},
};

static NSData *DecompressLZFSE(NSData *compressedData) {
  if (!compressedData.length) {
    return nil;
  }
  
  // Assume a compression ratio of 1.25.
  size_t bufferSize = compressedData.length * 1.25;
  
  while (true) {
    uint8_t *buffer = (uint8_t *)malloc(bufferSize);
    size_t decodedSize = compression_decode_buffer(
        buffer, bufferSize, (const uint8_t *)compressedData.bytes, compressedData.length,
        nil, COMPRESSION_LZFSE);
    if (decodedSize == 0) {
      free(buffer);
      return nil;
    }
    if (decodedSize == bufferSize) {
      // The buffer wasn't big enough - try again.
      free(buffer);
      bufferSize *= 1.25;
      continue;
    }
    return [NSData dataWithBytesNoCopy:buffer length:decodedSize];
  }
}

@interface TKMOfflineAudioViewController () <TKMDownloadModelDelegate,
                                             NSURLSessionDownloadDelegate>

@end

@implementation TKMOfflineAudioViewController {
  NSURLSession *_urlSession;
  TKMTableModel *_model;
  NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *_downloads;
  NSMutableDictionary<NSString *, NSIndexPath *> *_indexPaths;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    _urlSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    _downloads = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)rerender {
  _indexPaths = [NSMutableDictionary dictionary];
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView];

  for (const AvailablePackage& package : kAvailablePackages) {
    TKMDownloadModelItem *item = [[TKMDownloadModelItem alloc] initWithFilename:package.filename
                                                                          title:package.title
                                                                       delegate:self];
    item.totalSizeBytes = package.sizeBytes;
    
    if ([_downloads objectForKey:package.filename]) {
      NSURLSessionDownloadTask *task = _downloads[package.filename];
      item.downloadingProgressBytes = task.countOfBytesReceived;
      item.state = TKMDownloadModelItemDownloading;
    } else if ([UserDefaults.installedAudioPackages containsObject:package.filename]) {
      item.state = TKMDownloadModelItemInstalledSelected;
    } else {
      item.state = TKMDownloadModelItemNotInstalled;
    }
    
    _indexPaths[package.filename] = [model addItem:item];
  }
  
  _model = model;
  [model reloadTable];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.navigationController.navigationBarHidden = NO;
  
  [self rerender];
}

- (void)didTapDownloadItem:(TKMDownloadModelItem *)item {
  switch (item.state) {
    case TKMDownloadModelItemNotInstalled:
      [self startDownloadFor:item.filename];
      break;
    case TKMDownloadModelItemDownloading:
      [self cancelDownloadFor:item.filename];
      break;
    default:
      break;
  }
}

- (void)startDownloadFor:(NSString *)filename {
  NSString *urlString = [NSString stringWithFormat:kURLPattern, filename];
  NSURLSessionDownloadTask *task = [_urlSession downloadTaskWithURL:[NSURL URLWithString:urlString]];
  _downloads[filename] = task;
  [task resume];
  [self rerender];
}

- (void)cancelDownloadFor:(NSString *)filename {
  NSURLSessionDownloadTask *task = _downloads[filename];
  [task cancel];
  [_downloads removeObjectForKey:filename];
  [self rerender];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
  NSURL *url = downloadTask.originalRequest.URL;
  NSString *filename = url.lastPathComponent;
  
  NSData *lzfseData = [NSData dataWithContentsOfURL:location];
  if (!lzfseData) {
    [self reportErrorOnMainThread:filename
                            title:@"Error reading data"
                          message:url.absoluteString];
    return;
  }
  
  NSData *tarData = DecompressLZFSE(lzfseData);
  if (!tarData) {
    [self reportErrorOnMainThread:filename
                            title:@"Error decompressing data"
                          message:url.absoluteString];
    return;
  }
  
  auto extractProgress = ^(float progress) {
    [self updateProgressOnMainThread:filename
                         updateBlock:^(TKMDownloadModelItem *item) {
                           item.state = TKMDownloadModelItemInstalling;
                           item.installingProgress = progress;
                         }];
  };
  
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  NSError *error;
  [fileManager createFilesAndDirectoriesAtPath:[TKMAudio cacheDirectoryPath]
                                   withTarData:tarData
                                         error:&error
                                      progress:extractProgress];
  
  if (error) {
    [self reportErrorOnMainThread:filename
                            title:@"Error extracting data"
                          message:url.absoluteString];
    return;
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableSet<NSString *> *installedPackages =
        [NSMutableSet setWithSet:UserDefaults.installedAudioPackages];
    [installedPackages addObject:filename];
    UserDefaults.installedAudioPackages = installedPackages;
    
    [_downloads removeObjectForKey:filename];
    [self rerender];
  });
}

- (void)reportErrorOnMainThread:(NSString *)filename
                          title:(NSString *)title
                        message:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    [_downloads removeObjectForKey:filename];
    
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {}];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
    [self rerender];
  });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  if (!error) {
    return;
  }
  if ([error.domain isEqual:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
    return;
  }
  
  NSString *filename = task.originalRequest.URL.lastPathComponent;
  [self reportErrorOnMainThread:filename
                          title:error.localizedDescription
                        message:task.originalRequest.URL.absoluteString];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  NSString *filename = downloadTask.originalRequest.URL.lastPathComponent;
  
  [self updateProgressOnMainThread:filename
                       updateBlock:^(TKMDownloadModelItem *item) {
                         item.state = TKMDownloadModelItemDownloading;
                         item.downloadingProgressBytes = totalBytesWritten;
                       }];
}

- (void)updateProgressOnMainThread:(NSString *)filename
                       updateBlock:(void(^)(TKMDownloadModelItem *))updateBlock {
  dispatch_async(dispatch_get_main_queue(), ^{
    // Try to update the visible cell without reloading the whole table.  This is a bit of a hack.
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_indexPaths[filename]];
    if (cell) {
      TKMDownloadModelView *view = (TKMDownloadModelView *)cell;
      TKMDownloadModelItem *item = (TKMDownloadModelItem *)view.item;
      updateBlock(item);
      [view updateProgress];
    }
  });
}

@end
