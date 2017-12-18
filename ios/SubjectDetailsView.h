#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "DataLoader.h"
#import "proto/Wanikani.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *kWKSubjectDetailsViewSegueIdentifier;

@interface WKSubjectDetailsView : WKWebView <WKNavigationDelegate>

@property (nonatomic) DataLoader *dataLoader;
@property (nonatomic) WKSubject *subject;
@property (nonatomic, weak) UIViewController *owner;

- (void)prepareSegue:(UIStoryboardSegue *)segue;

@end

NS_ASSUME_NONNULL_END

