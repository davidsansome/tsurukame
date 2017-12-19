#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "DataLoader.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WKSubjectDetailsLinkHandler
- (void)openSubject:(WKSubject *)subject;
@end

@interface WKSubjectDetailsView : WKWebView <WKNavigationDelegate>

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) WKSubject *subject;
@property (nonatomic, weak) id<WKSubjectDetailsLinkHandler> linkHandler;

@property (nonatomic, readonly) WKSubject *lastSubjectClicked;

@end

NS_ASSUME_NONNULL_END

