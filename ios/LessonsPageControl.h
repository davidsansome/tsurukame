#import <UIKit/UIKit.h>

#import "proto/Wanikani.pbobjc.h"

@interface LessonsPageControl : UIControl

@property(nonatomic, copy) NSArray<WKSubject *> *subjects;
@property(nonatomic) NSInteger currentPageIndex;

@end
