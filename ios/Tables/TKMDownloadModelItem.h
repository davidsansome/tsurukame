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

#import "TKMModelItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum TKMDownloadModelItemState {
  TKMDownloadModelItemNotInstalled,
  TKMDownloadModelItemDownloading,
  TKMDownloadModelItemInstalledNotSelected,
  TKMDownloadModelItemInstalledSelected,
} TKMDownloadModelItemState;

@class TKMDownloadModelItem;

@protocol TKMDownloadModelDelegate <NSObject>

- (void)didTapDownloadItem:(TKMDownloadModelItem *)item;

@end

@interface TKMDownloadModelItem : NSObject <TKMModelItem>

- (instancetype)initWithFilename:(NSString *)filename
                           title:(NSString *)title
                        delegate:(id<TKMDownloadModelDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) NSString *filename;
@property(nonatomic, readonly) NSString *title;
@property(nonatomic, readonly) id<TKMDownloadModelDelegate> delegate;

@property(nonatomic) TKMDownloadModelItemState state;
@property(nonatomic) int64_t totalSizeBytes;
@property(nonatomic) int64_t downloadingProgressBytes;

@end

@interface TKMDownloadModelView : TKMModelCell

- (void)updateDownloadProgress;

@end

NS_ASSUME_NONNULL_END
