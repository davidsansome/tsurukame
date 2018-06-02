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

@class WKModelCell;

extern void WKSafePerformSelector(id target, SEL selector, id object);

@protocol WKModelItem <NSObject>

@required
- (Class)cellClass;

@optional
- (NSString *)cellReuseIdentifier;
- (WKModelCell *)createCell;

@end

@interface WKModelCell : UITableViewCell

@property(nonatomic, readonly, weak) id<WKModelItem> item;

- (void)updateWithItem:(id<WKModelItem>)item;

- (void)didSelectCell;

@end
