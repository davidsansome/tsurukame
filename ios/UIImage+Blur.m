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

#import "UIImage+Blur.h"

#import <Accelerate/Accelerate.h>

@implementation UIImage (Blur)

- (UIImage *)blurredImageWithRadius:(CGFloat)radius
                         iterations:(NSUInteger)iterations
                          tintColor:(nullable UIColor *)tintColor {
  if (self.size.width <= 0.f || self.size.height <= 0.f) {
    return self;
  }
  
  // boxSize must be an odd integer.
  uint32_t boxSize = (uint32_t)(radius * self.scale);
  if (boxSize % 2 == 0) {
    boxSize ++;
  }
  
  CGImageRef imageRef = self.CGImage;
  
  NSAssert(CGImageGetBitsPerPixel(imageRef) == 32, @"Image must be 32 bits per pixel (was %ld)",
           CGImageGetBitsPerPixel(imageRef));
  NSAssert(CGImageGetBitsPerComponent(imageRef) == 8, @"Image must have 8 bits per component (was %ld)",
           CGImageGetBitsPerComponent(imageRef));
  
  vImage_Buffer buffer1, buffer2;
  buffer1.width = buffer2.width = CGImageGetWidth(imageRef);
  buffer1.height = buffer2.height = CGImageGetHeight(imageRef);
  buffer1.rowBytes = buffer2.rowBytes = CGImageGetBytesPerRow(imageRef);
  size_t bytes = buffer1.rowBytes * buffer1.height;
  buffer1.data = malloc(bytes);
  buffer2.data = malloc(bytes);
  
  // Create temp buffer
  void *tempBuffer = malloc((size_t)vImageBoxConvolve_ARGB8888(
      &buffer1, &buffer2, NULL, 0, 0, boxSize, boxSize, NULL,
      kvImageEdgeExtend + kvImageGetTempBufferSize));
  
  // Copy image data
  CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
  CFDataRef dataSource = CGDataProviderCopyData(provider);
  const UInt8 *dataSourceData = CFDataGetBytePtr(dataSource);
  CFIndex dataSourceLength = CFDataGetLength(dataSource);
  memcpy(buffer1.data, dataSourceData, MIN(bytes, dataSourceLength));
  CFRelease(dataSource);
  
  for (NSUInteger i = 0; i < iterations; i++) {
    vImageBoxConvolve_ARGB8888(&buffer1, &buffer2, tempBuffer, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
    
    // Swap buffers
    void *temp = buffer1.data;
    buffer1.data = buffer2.data;
    buffer2.data = temp;
  }
  free(buffer2.data);
  free(tempBuffer);
  
  // Create image context from buffer
  CGContextRef ctx = CGBitmapContextCreate(buffer1.data, buffer1.width, buffer1.height,
                                           8, buffer1.rowBytes, CGImageGetColorSpace(imageRef),
                                           CGImageGetBitmapInfo(imageRef));
  
  // Apply tint
  if (tintColor && CGColorGetAlpha(tintColor.CGColor) > 0.0f) {
    CGContextSetFillColorWithColor(ctx, [tintColor colorWithAlphaComponent:0.25].CGColor);
    CGContextSetBlendMode(ctx, kCGBlendModePlusLighter);
    CGContextFillRect(ctx, CGRectMake(0, 0, buffer1.width, buffer1.height));
  }
  
  // Create image from context
  imageRef = CGBitmapContextCreateImage(ctx);
  UIImage *image = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
  CGImageRelease(imageRef);
  CGContextRelease(ctx);
  free(buffer1.data);
  return image;
}

@end

