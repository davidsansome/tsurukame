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

#import "DataLoader.h"
#import "proto/Wanikani.pbobjc.h"
#import "Tables/TKMSubjectModelItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface TKMSubjectDetailsView : UITableView

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic, weak) id<TKMSubjectDelegate> subjectDelegate;
@property (nonatomic) bool showHints;

@property (nonatomic, readonly) TKMSubject *lastSubjectClicked;

- (void)updateWithSubject:(TKMSubject *)subject
           studyMaterials:(TKMStudyMaterials *)studyMaterials
               assignment:(nullable TKMAssignment *)assignment;

@end

NS_ASSUME_NONNULL_END

