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

