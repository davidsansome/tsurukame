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

#import "TKMBlurrableCell.h"
#import "UIImage+Blur.h"

static const CGFloat kBlurRadius = 7.f;
static const int kBlurIterations = 5;
static const CGFloat kBlurToggleDuration = 0.25f;

@implementation TKMBlurrableCell {
  UIView *_blurView;
  bool _isBlurred;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    _blurBackgroundColor = [UIColor whiteColor];
  }
  return self;
}

- (void)setBlurrable:(bool)blurrable {
  _blurrable = blurrable;
  _isBlurred = blurrable;
  
  if (blurrable) {
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    UIImage *image = [UIImage imageNamed:@"baseline_remove_red_eye_black_24pt"];
    [button setTintColor:[UIColor lightGrayColor]];
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self
               action:@selector(didTapBlurButton:)
     forControlEvents:UIControlEventTouchUpInside];
    self.accessoryView = button;
    
    _blurView = [[UIView alloc] initWithFrame:self.contentView.bounds];
    [self.contentView addSubview:_blurView];
  } else {
    self.accessoryView = nil;
    [_blurView removeFromSuperview];
    _blurView = nil;
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  _blurView.frame = self.contentView.bounds;
  [self updateBlurView];
}

- (void)updateWithItem:(id<TKMModelItem>)item {
  [super updateWithItem:item];
  [self updateBlurView];
}

- (NSArray<UIView *> *)viewsToBlur {
  return @[self.contentView];
}

- (void)updateBlurView {
  if (!_blurView || CGRectIsEmpty(_blurView.frame)) {
    return;
  }
  
  CGFloat scaleFactor = self.contentView.contentScaleFactor;
  
  // Don't blur the bottom of the cell.
  CGRect rect = _blurView.frame;
  rect.size.height = floor(rect.size.height - 1.f / scaleFactor);
  
  // Hide the overlay for taking the screenshot.
  CGFloat originalAlpha = _blurView.alpha;
  _blurView.alpha = 0.f;
  
  // Screenshot the content view.
  UIGraphicsBeginImageContextWithOptions(rect.size, YES, scaleFactor);
  CGContextRef context = UIGraphicsGetCurrentContext();
  [_blurBackgroundColor set];
  UIRectFill(rect);
  for (UIView *view in self.viewsToBlur) {
    CGPoint origin = view.frame.origin;
    CGContextTranslateCTM(context, origin.x, origin.y);
    [view.layer renderInContext:context];
  }
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  // Blur the screenshot.
  UIImage *blurredImage = [image blurredImageWithRadius:kBlurRadius
                                             iterations:kBlurIterations
                                              tintColor:nil];
  _blurView.layer.contents = (id)blurredImage.CGImage;
  _blurView.alpha = originalAlpha;
}

- (void)didTapBlurButton:(UIButton *)button {
  _isBlurred = !_isBlurred;
  [UIView animateWithDuration:kBlurToggleDuration animations:^{
    _blurView.alpha = _isBlurred ? 1.f : 0.f;
  }];
}

@end
