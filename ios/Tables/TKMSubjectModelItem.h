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
#import "TKMSubjectChip.h"
#import "TKMSubjectDelegate.h"
#import "proto/Wanikani.pbobjc.h"

@class DataLoader;

NS_ASSUME_NONNULL_BEGIN;

@interface TKMSubjectModelView : TKMModelCell

- (void)setShowAnswers:(bool)showAnswers animated:(bool)animated;

@end

@interface TKMSubjectModelItem : NSObject <TKMModelItem>

/** Used for review summary.  Shows the meaning or reading in bold if they were wrong. */
- (instancetype)initWithSubject:(TKMSubject *)subject
                       delegate:(nullable id<TKMSubjectDelegate>)delegate
                   readingWrong:(bool)readingWrong
                   meaningWrong:(bool)meaningWrong NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithSubject:(TKMSubject *)subject
                     assignment:(TKMAssignment *)assignment
                       delegate:(nullable id<TKMSubjectDelegate>)delegate;

- (instancetype)initWithSubject:(TKMSubject *)subject
                       delegate:(nullable id<TKMSubjectDelegate>)delegate;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, copy) TKMSubject *subject;
@property(nonatomic) TKMAssignment *assignment;
@property(nonatomic, nullable, weak) id<TKMSubjectDelegate> delegate;
@property(nonatomic) bool readingWrong;
@property(nonatomic) bool meaningWrong;
@property(nonatomic) bool showLevelNumber;
@property(nonatomic) bool showAnswers;
@property(nonatomic) bool showRemaining;
@property(nonatomic) NSArray<id> *gradientColors;

@end

@interface TKMSubjectCollectionModelItem : NSObject <TKMModelItem>

- (instancetype)initWithSubjects:(GPBInt32Array *)subjects
                      dataLoader:(DataLoader *)dataLoader
                        delegate:(nullable id<TKMSubjectChipDelegate>)delegate
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, copy) GPBInt32Array *subjects;
@property(nonatomic) DataLoader *dataLoader;
@property(nonatomic, nullable, weak) id<TKMSubjectChipDelegate> delegate;

@end

NS_ASSUME_NONNULL_END;
