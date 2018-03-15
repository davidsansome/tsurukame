#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "DataLoader.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, WKSubjectDetailsViewStyle) {
  WKSubjectDetailsViewStyleComponents = 1 << 0,
  WKSubjectDetailsViewStyleMeaning    = 1 << 1,
  WKSubjectDetailsViewStyleReading    = 1 << 2,
  WKSubjectDetailsViewStyleExamples   = 1 << 3,
  
  WKSubjectDetailsViewStyleHint       = 1 << 4,
  
  WKSubjectDetailsViewStyleAllReviewSections =
      WKSubjectDetailsViewStyleComponents |
      WKSubjectDetailsViewStyleMeaning |
      WKSubjectDetailsViewStyleReading |
      WKSubjectDetailsViewStyleExamples,
};

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
@property (nonatomic) WKSubjectDetailsViewStyle style;

@property (nonatomic, readonly) WKSubject *lastSubjectClicked;

- (void)updateWithSubject:(WKSubject *)subject studyMaterials:(WKStudyMaterials *)studyMaterials;

@end

NS_ASSUME_NONNULL_END

