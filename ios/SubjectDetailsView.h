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
#import <WebKit/WebKit.h>

#import "DataLoader.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@class WKSubjectDetailsView;

@protocol WKSubjectDetailsDelegate <NSObject>
@optional
- (void)openSubject:(WKSubject *)subject;
- (void)subjectDetailsView:(WKSubjectDetailsView *)view
       didFinishNavigation:(WKNavigation *)navigation;
@end

@interface WKSubjectDetailsView : WKWebView <WKNavigationDelegate>

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic, weak) id<WKSubjectDetailsDelegate> delegate;
@property (nonatomic) bool showHints;

@property (nonatomic, readonly) WKSubject *lastSubjectClicked;

- (void)updateWithSubject:(WKSubject *)subject studyMaterials:(WKStudyMaterials *)studyMaterials;

@end

NS_ASSUME_NONNULL_END

