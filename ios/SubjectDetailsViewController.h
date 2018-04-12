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
#import "LocalCachingClient.h"
#import "SubjectDetailsView.h"
#import "proto/Wanikani.pbobjc.h"

@interface SubjectDetailsViewController : UIViewController

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) LocalCachingClient *localCachingClient;
@property (nonatomic) WKSubject *subject;

// If this is set to true before the view is loaded, the back button will be hidden.
@property (nonatomic) bool hideBackButton;

// If this is set to true before the view is loaded, kanji hints will be displayed.
@property (nonatomic) bool showHints;

// If this is set to true before the view is loaded, the user's progress will be included.
@property (nonatomic) bool showUserProgress;

// The index of this subject in some other collection.  Unused, for convenience only.
@property (nonatomic) NSInteger index;

@end
