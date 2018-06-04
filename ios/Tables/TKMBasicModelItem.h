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

#import <Foundation/Foundation.h>

#import "TKMModelItem.h"

@interface TKMBasicModelCell : TKMModelCell
@end

@interface TKMBasicModelItem : NSObject <TKMModelItem>

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType
                       target:(id)target
                       action:(SEL)action NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(NSString *)title
                     subtitle:(NSString *)subtitle;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic) UITableViewCellStyle style;
@property(nonatomic) NSString *title;
@property(nonatomic) NSString *subtitle;
@property(nonatomic) UITableViewCellAccessoryType accessoryType;
@property(nonatomic, weak) id target;
@property(nonatomic) SEL action;

@property(nonatomic) UIColor *textColor;

@end

#define TKM_BASIC_MODEL_ITEM_INITIALISERS_UNAVAILABLE \
  - (instancetype)initWithStyle:(UITableViewCellStyle)style \
                          title:(NSString *)title \
                       subtitle:(NSString *)subtitle \
                  accessoryType:(UITableViewCellAccessoryType)accessoryType \
                         target:(id)target \
                         action:(SEL)action NS_UNAVAILABLE; \
  - (instancetype)initWithStyle:(UITableViewCellStyle)style \
                          title:(NSString *)title \
                       subtitle:(NSString *)subtitle \
                  accessoryType:(UITableViewCellAccessoryType)accessoryType NS_UNAVAILABLE; \
  - (instancetype)initWithStyle:(UITableViewCellStyle)style \
                          title:(NSString *)title \
                       subtitle:(NSString *)subtitle NS_UNAVAILABLE; \
  - (instancetype)init NS_UNAVAILABLE;
