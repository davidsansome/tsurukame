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

NS_ASSUME_NONNULL_BEGIN;

@interface TKMBasicModelCell : TKMModelCell
@end

@interface TKMBasicModelItem : NSObject <TKMModelItem>

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType
                       target:(nullable id)target
                       action:(nullable SEL)action NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle
                accessoryType:(UITableViewCellAccessoryType)accessoryType;

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                        title:(nullable NSString *)title
                     subtitle:(nullable NSString *)subtitle;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) UITableViewCellStyle style;

@property(nonatomic, nullable) NSString *title;
@property(nonatomic, nullable) UIFont *titleFont;
@property(nonatomic, nullable) UIColor *titleTextColor;
@property(nonatomic) int numberOfTitleLines;

@property(nonatomic, nullable) NSString *subtitle;
@property(nonatomic, nullable) UIFont *subtitleFont;
@property(nonatomic, nullable) UIColor *subtitleTextColor;
@property(nonatomic) int numberOfSubtitleLines;

@property(nonatomic) UITableViewCellAccessoryType accessoryType;

@property(nonatomic) UIImage *image;

@property(nonatomic, nullable, weak) id target;
@property(nonatomic, nullable) SEL action;

@property(nonatomic) UIColor *textColor;
@property(nonatomic) UIColor *imageTintColor;
@property(nonatomic) bool enabled;

@property(nonatomic, nullable, weak) TKMBasicModelCell *cell;

@end

#define TKM_BASIC_MODEL_ITEM_INITIALISERS_UNAVAILABLE                                       \
  -(instancetype)initWithStyle : (UITableViewCellStyle)style title                          \
      : (nullable NSString *)title subtitle : (nullable NSString *)subtitle accessoryType   \
      : (UITableViewCellAccessoryType)accessoryType target : (nullable id)target action     \
      : (nullable SEL)action NS_UNAVAILABLE;                                                \
  -(instancetype)initWithStyle : (UITableViewCellStyle)style title                          \
      : (nullable NSString *)title subtitle : (nullable NSString *)subtitle accessoryType   \
      : (UITableViewCellAccessoryType)accessoryType NS_UNAVAILABLE;                         \
  -(instancetype)initWithStyle : (UITableViewCellStyle)style title                          \
      : (nullable NSString *)title subtitle : (nullable NSString *)subtitle NS_UNAVAILABLE; \
  -(instancetype)init NS_UNAVAILABLE;

NS_ASSUME_NONNULL_END;
