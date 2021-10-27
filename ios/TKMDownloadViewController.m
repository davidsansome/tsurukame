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

#import "TKMDownloadViewController.h"
#import "Tsurukame-Swift.h"

#import "Tables/TKMDownloadModelItem.h"

@interface TKMDownloadViewController () <NSURLSessionDownloadDelegate>

@end

@implementation TKMDownloadViewController {
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

#pragma mark - Abstract methods.

- (void)populateModel:(TKMMutableTableModel *)model {
  [self doesNotRecognizeSelector:_cmd];
}
- (NSURL *)urlForFilename:(NSString *)filename {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}
- (void)didFinishDownloadFor:(NSString *)filename atURL:(NSURL *)location {
  [self doesNotRecognizeSelector:_cmd];
}
- (void)toggleItem:(NSString *)filename selected:(BOOL)selected {
  [self doesNotRecognizeSelector:_cmd];
}

#pragma mark - Utilities.

- (NSURLSessionDownloadTask *)activeDownloadFor:(NSString *)filename {
  return _downloads[filename];
}

- (void)rerender {
  TKMMutableTableModel *model = [[TKMMutableTableModel alloc] initWithTableView:self.tableView
                                                                       delegate:nil];
  [self populateModel:model];

  // Index the items.
  _indexPaths = [NSMutableDictionary dictionary];
  for (int section = 0; section < model.sectionCount; ++section) {
    NSArray<id<TKMModelItem>> *items = [model itemsInSection:section];
    for (int i = 0; i < items.count; ++i) {
      if ([items[i] isKindOfClass:TKMDownloadModelItem.class]) {
        TKMDownloadModelItem *downloadItem = (TKMDownloadModelItem *)items[i];
        _indexPaths[downloadItem.filename] = [NSIndexPath indexPathForItem:i inSection:section];
      }
    }
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
      [self startDownloadFor:item];
      break;
    case TKMDownloadModelItemDownloading:
      [self cancelDownloadFor:item];
      break;
    case TKMDownloadModelItemInstalledNotSelected:
      [self toggleItem:item.filename selected:YES];
      [self rerender];
      break;
    case TKMDownloadModelItemInstalledSelected:
      [self toggleItem:item.filename selected:NO];
      [self rerender];
      break;
    case TKMDownloadModelItemInstalling:
      break;
  }
}

- (void)startDownloadFor:(TKMDownloadModelItem *)item {
  NSURL *url = [self urlForFilename:item.filename];
  NSLog(@"Downloading %@", url);
  NSURLSessionDownloadTask *task = [_urlSession downloadTaskWithURL:url];
  _downloads[item.filename] = task;
  [task resume];
  [self rerender];
}

- (void)cancelDownloadFor:(TKMDownloadModelItem *)item {
  NSURLSessionDownloadTask *task = _downloads[item.filename];
  [task cancel];
  [_downloads removeObjectForKey:item.filename];
  [self rerender];
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
  NSURL *url = downloadTask.originalRequest.URL;
  NSString *filename = url.lastPathComponent;

  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)downloadTask.response;
  if (httpResponse.statusCode != 200) {
    [self reportErrorOnMainThread:filename
                            title:[NSString stringWithFormat:@"HTTP error %ld",
                                                             (long)httpResponse.statusCode]
                          message:url.absoluteString];
    return;
  }

  [self didFinishDownloadFor:filename atURL:location];
};

- (void)updateProgressOnMainThread:(NSString *)filename
                       updateBlock:(void (^)(TKMDownloadModelItem *))updateBlock {
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

- (void)reportErrorOnMainThread:(nullable NSString *)filename
                          title:(NSString *)title
                        message:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (filename) {
      [_downloads removeObjectForKey:filename];
    }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action){
                                                   }];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
    [self rerender];
  });
}

- (void)markDownloadComplete:(NSString *)filename {
  [_downloads removeObjectForKey:filename];
  [self rerender];
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

@end
