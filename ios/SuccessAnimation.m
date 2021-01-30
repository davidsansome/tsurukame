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

#import "SuccessAnimation.h"
#import "Tsurukame-Swift.h"

static CGFloat RandFloat(CGFloat min, CGFloat max) {
  return ((CGFloat)arc4random()) / ((CGFloat)UINT32_MAX) * (max - min) + min;
}

static void CreateSpark(UIView *superview,
                        CGPoint origin,
                        CGFloat size,
                        CGFloat distance,
                        CGFloat radians,
                        UIColor *color,
                        NSTimeInterval duration) {
  CGRect frame = CGRectMake(origin.x - size / 2, origin.y - size / 2, size, size);
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
                   }
                   completion:nil];

  // Explode.
  [UIView animateWithDuration:duration * 0.4
                        delay:0
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     view.center = CGPointMake(view.center.x - distance * sin(radians),
                                               view.center.y - distance * cos(radians));
                     [superview layoutIfNeeded];
                   }
                   completion:nil];

  // Get smaller.
  [UIView animateWithDuration:duration * 0.8
      delay:duration * 0.2
      options:UIViewAnimationOptionCurveLinear
      animations:^{
        view.transform = CGAffineTransformScale(view.transform, 0.001, 0.001);
        [superview layoutIfNeeded];
      }
      completion:^(BOOL finished) {
        [view removeFromSuperview];
      }];

  // Fade out.
  [UIView animateWithDuration:duration * 0.2
                        delay:duration * 0.8
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     view.alpha = 0.0;
                   }
                   completion:nil];
}

void CreatePlusOneText(UIView *toView, NSString *text, UIFont *font, UIColor *color,
                       CGFloat duration) {
  UIView *superview = toView.superview;

  UILabel *view = [[UILabel alloc] initWithFrame:CGRectZero];
  view.text = text;
  view.font = font;
  view.textColor = color;
  view.alpha = 0.0;
  [view sizeToFit];
  view.center = CGPointMake(toView.center.x, toView.center.y + font.pointSize * 1.5);
  view.transform = CGAffineTransformMakeScale(0.1, 0.1);
  [superview addSubview:view];
  [superview layoutIfNeeded];

  // Fade in.
  [UIView animateWithDuration:duration * 0.1
                        delay:0
                      options:UIViewAnimationOptionCurveLinear
                   animations:^{
                     view.alpha = 1.0;
                   }
                   completion:nil];

  // Get bigger.
  [UIView animateWithDuration:duration * 0.2
                        delay:0.0
       usingSpringWithDamping:0.5
        initialSpringVelocity:1
                      options:0
                   animations:^{
                     view.transform = CGAffineTransformIdentity;
                   }
                   completion:nil];

  // Move to destination and get smaller
  [UIView animateWithDuration:duration * 0.3
      delay:duration * 0.7
      options:UIViewAnimationOptionCurveLinear
      animations:^{
        view.center = toView.center;
        view.transform = CGAffineTransformMakeScale(0.1, 0.1);
        view.alpha = 0.1;
      }
      completion:^(BOOL finished) {
        [view removeFromSuperview];
      }];
}

void CreateSpringyBillboard(UIView *originView,
                            NSString *text,
                            UIFont *font,
                            UIColor *textColor,
                            UIColor *backgroundColor,
                            CGFloat cornerRadius,
                            CGFloat padding,
                            CGFloat distance,
                            CGFloat duration) {
  const CGFloat angleRadians = RandFloat(-M_PI * 0.1, M_PI * 0.1);
  UIView *superview = originView.superview;

  CGFloat hue, saturation, alpha;
  [backgroundColor getHue:&hue saturation:&saturation brightness:nil alpha:&alpha];
  UIColor *borderColor = [UIColor colorWithHue:hue
                                    saturation:saturation / 2
                                    brightness:1.0
                                         alpha:alpha];

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
                   }
                   completion:nil];

  // Spring to target position.
  [UIView animateWithDuration:duration * 0.3
                        delay:0.0
       usingSpringWithDamping:0.5
        initialSpringVelocity:1
                      options:0
                   animations:^{
                     container.center =
                         CGPointMake(container.center.x + distance * sin(angleRadians),
                                     container.center.y - distance * cos(angleRadians));
                     [superview layoutIfNeeded];
                   }
                   completion:nil];

  // Get smaller and fade out.
  [UIView animateWithDuration:duration * 0.1
      delay:duration * 0.85
      options:UIViewAnimationOptionCurveEaseInOut
      animations:^{
        container.transform = CGAffineTransformScale(container.transform, 0.001, 0.001);
        container.alpha = 0.0;
        [superview layoutIfNeeded];
      }
      completion:^(BOOL finished) {
        [label removeFromSuperview];
      }];
}

static void CreateExplosion(UIView *view) {
  const CGFloat kSizeMin = 9.0;
  const CGFloat kSizeMax = 11.0;
  const CGFloat kDistanceMin = 60.0;
  const CGFloat kDistanceMax = 150.0;
  const CGFloat kDurationMin = 0.5;
  const CGFloat kDurationMax = 0.7;
  const CGFloat kOriginCenterOffsetRange = 0.25;
  const CGFloat kAngleRange = M_PI * 0.3;
  static UIColor *color1;
  static UIColor *color2;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    color1 = [UIColor colorWithRed:247.0 / 255 green:181.0 / 255 blue:74.0 / 255 alpha:1.0];
    color2 = [UIColor colorWithRed:230.0 / 255 green:57.0 / 255 blue:91.0 / 255 alpha:1.0];
  });

  UIView *superview = view.superview;
  for (int i = 0; i < 80; ++i) {
    CGFloat size = RandFloat(kSizeMin, kSizeMax);
    CGFloat distance = RandFloat(kDistanceMin, kDistanceMax);
    CGFloat duration = RandFloat(kDurationMin, kDurationMax);
    CGFloat offset = RandFloat(-1.0, 1.0);
    CGFloat angle = -kAngleRange * offset;
    CGFloat originCenterOffset = kOriginCenterOffsetRange * offset;
    UIColor *color = arc4random_uniform(2) ? color1 : color2;
    CGPoint origin =
        CGPointMake(view.center.x + originCenterOffset * view.bounds.size.width, view.center.y);

    CreateSpark(superview, origin, size, distance, angle, color, duration);
  }
}

/**
 Specialized version of CreateExplosion that attempt to line up the sparks
 with the characters in the SRS level dots label. The arc is also skewed
 left so the sparks stay on screen.
 */
static void CreateDotExplosion(UILabel *view) {
  const CGFloat kSizeMin = 9.0;
  const CGFloat kSizeMax = 11.0;
  const CGFloat kDistanceMin = 30.0;
  const CGFloat kDistanceMax = 80.0;
  const CGFloat kDurationMin = 0.5;
  const CGFloat kDurationMax = 0.7;
  const CGFloat kAngleRange = M_PI * 0.3;

  NSAttributedString *value = view.attributedText;
  int dotCount = (int)value.length;
  CGFloat letterWidth = view.bounds.size.width / dotCount;

  UIView *superview = view.superview;
  for (int i = 0; i < dotCount; ++i) {
    CGFloat size = RandFloat(kSizeMin, kSizeMax);
    CGFloat distance = RandFloat(kDistanceMin, kDistanceMax);
    CGFloat duration = RandFloat(kDurationMin, kDurationMax);
    CGFloat offset = RandFloat(-1.5, 0.0);
    CGFloat angle = -kAngleRange * offset;
    UIColor *color = [value attribute:NSForegroundColorAttributeName atIndex:i effectiveRange:nil];
    CGPoint origin = CGPointMake(view.frame.origin.x + (i * letterWidth), view.center.y);

    CreateSpark(superview, origin, size, distance, angle, color, duration);
  }
}

void RunSuccessAnimation(UIView *answerField,
                         UIView *doneLabel,
                         UILabel *srsLevelLabel,
                         bool isSubjectFinished,
                         bool didLevelUp,
                         NSInteger newSrsStage) {
  if (Settings.animateParticleExplosion) {
    CreateExplosion(answerField);
  }

  if (isSubjectFinished && Settings.animatePlusOne) {
    CreatePlusOneText(doneLabel,
                      @"+1",
                      [UIFont boldSystemFontOfSize:20.0],
                      [UIColor whiteColor],
                      1.5);  // Duration.
  }

  if (isSubjectFinished && Settings.showSRSLevelIndicator) {
    CreateDotExplosion(srsLevelLabel);
  }

  if (isSubjectFinished && didLevelUp && Settings.animateLevelUpPopup) {
    UIColor *srsLevelColor;
    switch (newSrsStage) {
      case 5:
        srsLevelColor = [UIColor colorWithRed:0.533 green:0.176 blue:0.62 alpha:1];  // #882d9e
        break;
      case 7:
        srsLevelColor = [UIColor colorWithRed:0.161 green:0.302 blue:0.859 alpha:1];  // #294ddb
        break;
      case 8:
        srsLevelColor = [UIColor colorWithRed:0 green:0.576 blue:0.867 alpha:1];  // #0093dd
        break;
      case 9:
        srsLevelColor = [UIColor colorWithRed:0.263 green:0.263 blue:0.263 alpha:1];  // #434343
        break;
      default:
        return;
    }
    NSString *srsLevelString = [TKMProtobufExtensions srsStageName:newSrsStage];

    CreateSpringyBillboard(answerField, srsLevelString, [UIFont systemFontOfSize:16.0],
                           [UIColor whiteColor], srsLevelColor,
                           5.0,    // Border radius.
                           6.0,    // Padding.
                           100.0,  // Distance.
                           3.0);   // Duration.
  }
}
