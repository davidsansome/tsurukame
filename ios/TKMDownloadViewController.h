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

#import <UIKit/UIKit.h>

#import "Tables/TKMDownloadModelItem.h"

@class TKMMutableTableModel;

NS_ASSUME_NONNULL_BEGIN

@interface TKMDownloadViewController : UITableViewController <TKMDownloadModelDelegate>

#pragma mark - Abstract methods.

- (void)populateModel:(TKMMutableTableModel *)model;

- (NSURL *)urlForFilename:(NSString *)filename;

// A download finished.  The subclass must move the file at the URL to the destination, and then
// call either reportErrorOnMainThread or markDownloadComplete.
- (void)didFinishDownloadFor:(NSString *)filename atURL:(NSURL *)location;

// Toggle a downloaded item's selected state to the given state.
- (void)toggleItem:(NSString *)filename selected:(BOOL)selected;

#pragma mark - Utilities.

// Returns the active download for the given filename, or nil.
- (nullable NSURLSessionDownloadTask *)activeDownloadFor:(NSString *)filename;

// Re-renders the table.  Must be called on the main thread.
- (void)rerender;

// Updates the item with the given filename.
- (void)updateProgressOnMainThread:(NSString *)filename
                       updateBlock:(void (^)(TKMDownloadModelItem *))updateBlock;

// Asynchronously shows an error dialog, and if filename is not nil, marks that download as
// finished.  Can be called on any thread.
- (void)reportErrorOnMainThread:(nullable NSString *)filename
                          title:(NSString *)title
                        message:(NSString *)message;

// Marks this download as complete and re-renders the table.  Must be called on the main thread.
- (void)markDownloadComplete:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
