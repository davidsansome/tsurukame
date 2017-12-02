#import <Foundation/Foundation.h>

@interface NSString (LevenshteinDistance)

- (float)levenshteinDistanceTo:(NSString *)other;

@end
