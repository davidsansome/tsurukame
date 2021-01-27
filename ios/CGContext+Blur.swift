// Copyright 2021 David Sansome
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

import Accelerate
import Foundation

extension CGContext {
  // Creates a new CGContext that draws to a bitmap suitable for drawing on the given UIScreen.
  class func screenBitmap(size: CGSize, screen: UIScreen) -> CGContext {
    let scale = screen.scale
    let w = Int(size.width * scale)
    let h = Int(size.height * scale)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ret = CGContext(data: nil, width: w, height: h,
                        bitsPerComponent: 8, bytesPerRow: w * 8, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast
                          .rawValue | CGBitmapInfo.byteOrder32Big
                          .rawValue)!
    ret.translateBy(x: 0, y: CGFloat(h))
    ret.scaleBy(x: scale, y: -scale)
    return ret
  }

  // Blurs this CGContext, writing the result to another CGContext.
  // kernelSize must be odd.
  func blur(to outCtx: CGContext, kernelSize: UInt32) {
    var inBuf = CGContext.makeVImageBuffer(self)
    var outBuf = CGContext.makeVImageBuffer(outCtx)

    CGContext.convolve(&inBuf, to: &outBuf, kernelSize: kernelSize)
    CGContext.convolve(&outBuf, to: &inBuf, kernelSize: kernelSize)
    CGContext.convolve(&inBuf, to: &outBuf, kernelSize: kernelSize)
  }

  // Runs the given function in this CGContext.
  func with(f: () -> Void) {
    UIGraphicsPushContext(self)
    f()
    UIGraphicsPopContext()
  }

  private class func makeVImageBuffer(_ ctx: CGContext) -> vImage_Buffer {
    vImage_Buffer(data: ctx.data, height: vImagePixelCount(ctx.height),
                  width: vImagePixelCount(ctx.width),
                  rowBytes: ctx.bytesPerRow)
  }

  private class func convolve(_ inBuf: inout vImage_Buffer, to outBuf: inout vImage_Buffer,
                              kernelSize: UInt32) {
    vImageBoxConvolve_ARGB8888(&inBuf, &outBuf, nil, 0, 0, kernelSize, kernelSize, nil,
                               vImage_Flags(kvImageEdgeExtend))
  }
}
