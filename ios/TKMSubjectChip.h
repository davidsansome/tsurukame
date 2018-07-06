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

#import "TKMSubjectDelegate.h"

@class TKMSubjectChip;

NS_ASSUME_NONNULL_BEGIN;

extern const UIEdgeInsets kTKMSubjectChipCollectionEdgeInsets;
NSArray<NSValue *> *TKMCalculateSubjectChipFrames(NSArray<TKMSubjectChip *> *chips, CGFloat width,
                                                  NSTextAlignment alignment);

@protocol TKMSubjectChipDelegate <NSObject>

- (void)didTapSubjectChip:(TKMSubjectChip *)chip;

@end

@interface TKMSubjectChip : UIView

- (instancetype)initWithSubject:(TKMSubject *)subject
                           font:(nullable UIFont *)font
                    showMeaning:(bool)showMeaning
                       delegate:(id<TKMSubjectChipDelegate>)delegate;

- (instancetype)initWithSubject:(nullable TKMSubject *)subject
                           font:(nullable UIFont *)font
                       chipText:(NSAttributedString *)chipText
                       sideText:(nullable NSAttributedString *)sideText
                  chipTextColor:(UIColor *)chipTextColor
                   chipGradient:(NSArray<id> *)chipGradient
                       delegate:(id<TKMSubjectChipDelegate>)delegate NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

@property(nonatomic, readonly, nullable) TKMSubject *subject;

@property(nonatomic, getter=isDimmed) bool dimmed;

@end

NS_ASSUME_NONNULL_END;
