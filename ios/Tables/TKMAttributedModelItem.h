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

#import "TKMBasicModelItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface TKMAttributedModelItem : NSObject <TKMModelItem>

- (instancetype)initWithText:(NSAttributedString *)text NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic) NSAttributedString *text;

@end

@interface TKMAttributedModelCell : TKMModelCell

@property(nonatomic, nullable) UIButton *rightButton;

@end

NS_ASSUME_NONNULL_END
