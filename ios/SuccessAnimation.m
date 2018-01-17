#import "SuccessAnimation.h"

static void CreateSpark(UIView *originView,
                        CGFloat size,
                        CGFloat distance,
                        CGFloat radians,
                        UIColor *color,
                        NSTimeInterval duration) {
  UIView *superview = originView.superview;
  
  CGRect frame = CGRectMake(originView.center.x - size / 2,
                            originView.center.y - size / 2,
                            size, size);
  UIView *view = [[UIView alloc] initWithFrame:frame];
  view.backgroundColor = color;
  view.layer.anchorPoint = CGPointMake(1.0, 1.0);
  view.layer.cornerRadius = size / 2;
  view.alpha = 0.0;
  [superview addSubview:view];
  [superview layoutIfNeeded];
  
  // Fade in.
  [UIView animateWithDuration:duration * 0.2
                        delay:0
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     view.alpha = 1.0;
                   } completion:nil];
  
  // Explode.
  [UIView animateWithDuration:duration * 0.4
                        delay:0
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     view.center = CGPointMake(view.center.x + distance * sin(radians),
                                               view.center.y + distance * cos(radians));
                     [superview layoutIfNeeded];
                   } completion:nil];
  
  // Get smaller.
  [UIView animateWithDuration:duration * 0.8
                        delay:duration * 0.2
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     view.transform = CGAffineTransformScale(view.transform, 0.001, 0.001);
                     [superview layoutIfNeeded];
                   } completion:^(BOOL finished) {
                     [view removeFromSuperview];
                   }];
  
  // Fade out.
  [UIView animateWithDuration:duration * 0.2
                        delay:duration * 0.8
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     view.alpha = 0.0;
                   } completion:nil];
}

void CreateFlyingText(UIView *fromView,
                      UIView *toView,
                      NSString *text,
                      UIFont *font,
                      UIColor *color,
                      CGFloat duration) {
  assert(toView.superview == fromView.superview);
  UIView *superview = fromView.superview;
  
  UILabel *view = [[UILabel alloc] initWithFrame:CGRectZero];
  view.text = text;
  view.font = font;
  view.textColor = color;
  view.alpha = 0.0;
  [view sizeToFit];
  view.center = fromView.center;
  [superview addSubview:view];
  [superview layoutIfNeeded];
  
  // Fade in.
  [UIView animateWithDuration:duration * 0.2
                        delay:0
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     view.alpha = 1.0;
                   } completion:nil];
  
  // Move to destination.
  UIViewPropertyAnimator *positionAnimator =
      [[UIViewPropertyAnimator alloc] initWithDuration:duration
                                         controlPoint1:CGPointMake(0.0, 0.0)
                                         controlPoint2:CGPointMake(0.0, 0.75)
                                            animations:^{
                                              view.center = toView.center;
                                            }];
  [positionAnimator addCompletion:^(UIViewAnimatingPosition finalPosition) {
    [view removeFromSuperview];
  }];
  [positionAnimator startAnimation];
  
  // Get smaller.
  [UIView animateWithDuration:duration * 0.5
                        delay:duration * 0.5
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     view.transform = CGAffineTransformScale(view.transform, 0.5, 0.5);
                     [superview layoutIfNeeded];
                   } completion:nil];
  
  // Fade out.
  [UIView animateWithDuration:duration * 0.3
                        delay:duration * 0.7
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     view.alpha = 0.2;
                   } completion:nil];
}

void CreateSpringyBillboard(UIView *originView,
                            NSString *text,
                            UIFont *font,
                            UIColor *textColor,
                            UIColor *backgroundColor,
                            CGFloat cornerRadius,
                            CGFloat padding,
                            CGFloat distance,
                            CGFloat angleRadians,
                            CGFloat duration) {
  UIView *superview = originView.superview;
  
  CGFloat hue, saturation, alpha;
  [backgroundColor getHue:&hue saturation:&saturation brightness:nil alpha:&alpha];
  UIColor *borderColor = [UIColor colorWithHue:hue saturation:saturation / 2 brightness:1.0 alpha:alpha];
  
  UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
  label.text = text;
  label.font = font;
  label.textColor = textColor;
  label.backgroundColor = backgroundColor;
  label.layer.cornerRadius = cornerRadius;
  label.layer.borderColor = borderColor.CGColor;
  label.layer.borderWidth = 1.5;
  label.clipsToBounds = YES;
  label.textAlignment = NSTextAlignmentCenter;
  [label sizeToFit];
  label.frame = CGRectInset(label.frame, -padding, -padding);
  
  UIView *container = [[UIView alloc] initWithFrame:label.frame];
  container.alpha = 0.0;
  container.center = originView.center;
  container.transform = CGAffineTransformMakeRotation(angleRadians);
  container.layer.shadowColor = [UIColor blackColor].CGColor;
  container.layer.shadowOffset = CGSizeMake(0, 0);
  container.layer.shadowOpacity = 0.5;
  container.layer.shadowRadius = 4;
  container.clipsToBounds = NO;
  [container addSubview:label];
  
  [superview addSubview:container];
  [superview layoutIfNeeded];
  
  // Fade in.
  [UIView animateWithDuration:duration * 0.15
                        delay:0
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     container.alpha = 1.0;
                   } completion:nil];
  
  // Spring to target position.
  [UIView animateWithDuration:duration * 0.3
                        delay:0.0
       usingSpringWithDamping:0.5
        initialSpringVelocity:1
                      options:0
                   animations:^{
                     container.center = CGPointMake(container.center.x + distance * sin(angleRadians),
                                                    container.center.y - distance * cos(angleRadians));
                     [superview layoutIfNeeded];
                   } completion:nil];
  
  // Get smaller and fade out.
  [UIView animateWithDuration:duration * 0.1
                        delay:duration * 0.85
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     container.transform = CGAffineTransformScale(container.transform, 0.001, 0.001);
                     container.alpha = 0.0;
                     [superview layoutIfNeeded];
                   } completion:^(BOOL finished) {
                     [label removeFromSuperview];
                   }];
}
                            

static CGFloat RandFloat(CGFloat min, CGFloat max) {
  return ((CGFloat)arc4random()) / ((CGFloat)UINT32_MAX) * (max - min) + min;
}

static void CreateExplosion(UIView *origin) {
  const CGFloat kSizeMin = 9.0;
  const CGFloat kSizeMax = 11.0;
  const CGFloat kDistanceMin = 15.0;
  const CGFloat kDistanceMax = 45.0;
  const CGFloat kDurationMin = 0.5;
  const CGFloat kDurationMax = 0.7;
  static UIColor *color1;
  static UIColor *color2;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    color1 = [UIColor colorWithRed:247.0/255 green:181.0/255 blue:74.0/255 alpha:1.0];
    color2 = [UIColor colorWithRed:230.0/255 green:57.0/255 blue:91.0/255 alpha:1.0];
  });
  
  for (int i = 0; i < 40; ++i) {
    CGFloat size = RandFloat(kSizeMin, kSizeMax);
    CGFloat distance = RandFloat(kDistanceMin, kDistanceMax);
    CGFloat duration = RandFloat(kDurationMin, kDurationMax);
    CGFloat angle = RandFloat(-M_PI, M_PI);
    UIColor *color = arc4random_uniform(2) ? color1 : color2;
    
    CreateSpark(origin, size, distance, angle, color, duration);
  }
}

void RunSuccessAnimation(UIView *button,
                         UIView *doneLabel,
                         bool isSubjectFinished,
                         int newSrsLevel) {
  CreateExplosion(button);
  if (!isSubjectFinished) {
    return;
  }
  
  CreateFlyingText(button,
                   doneLabel,
                   @"+1",
                   [UIFont boldSystemFontOfSize:20.0],
                   [UIColor whiteColor],
                   0.75);  // Duration.
  
  NSString *srsLevelString;
  UIColor *srsLevelColor;
  switch (newSrsLevel) {
    case 5:
      srsLevelString = @"Guru";
      srsLevelColor = [UIColor colorWithRed:0.533 green:0.176 blue:0.62 alpha:1]; // #882d9e
      break;
    case 7:
      srsLevelString = @"Master";
      srsLevelColor = [UIColor colorWithRed:0.161 green:0.302 blue:0.859 alpha:1]; // #294ddb
      break;
    case 8:
      srsLevelString = @"Enlightened";
      srsLevelColor = [UIColor colorWithRed:0 green:0.576 blue:0.867 alpha:1]; // #0093dd
      break;
    case 9:
      srsLevelString = @"Burned";
      srsLevelColor = [UIColor colorWithRed:0.263 green:0.263 blue:0.263 alpha:1]; // #434343
      break;
    default:
      return;
  }
  
  CreateSpringyBillboard(button, srsLevelString,
                         [UIFont systemFontOfSize:16.0],
                         [UIColor whiteColor],
                         srsLevelColor,
                         5.0,  // Border radius.
                         6.0,  // Padding.
                         50.0,  // Distance.
                         - M_PI * 0.15,  // Angle.
                         3.0);  // Duration.
}
