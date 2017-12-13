#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKKanaInput : NSObject <UITextFieldDelegate>

- (instancetype)initWithDelegate:(id<UITextFieldDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic) bool enabled;

@end

NS_ASSUME_NONNULL_END
