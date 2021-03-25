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

// Updating font screenshots:
// 1. Run the test in this file.
// 2. Open the "Test" entry for this test in XCode's "Report navigator" tab.
// 3. Click the paperclip next to each Attachment line in the log, and save the screenshot.

import XCTest

class FontScreenshotterUITests: XCTestCase {
  let app = XCUIApplication()

  override func setUp() {
    continueAfterFailure = false
    app.launch()
  }

  func testScreenshotFontPreviews() {
    // Find all the font preview elements.
    let elements = app.tables.cells.staticTexts.matching(identifier: "preview")
    for i in 0 ... elements.count {
      let element = elements.element(boundBy: i)
      if !element.exists {
        continue
      }

      let original = element.screenshot().image.cgImage!
      let w = Int(original.width)
      let h = Int(original.height)

      XCTAssertEqual(original.alphaInfo, CGImageAlphaInfo.noneSkipFirst)

      // Copy the image's pixel data and get a mutable pointer to it.
      let data = CFDataCreateMutableCopy(nil, 0, original.dataProvider!.data)
      let ptr = CFDataGetMutableBytePtr(data)!

      // Set the alpha channel of each pixel.  The data layout is RGBA.
      for y in 0 ..< h {
        for x in 0 ..< w {
          ptr[(y * w + x) * 4 + 3] = 255 - ptr[(y * w + x) * 4 + 0]
        }
      }

      // Create a new CGImage from the modified data.
      let img = CGImage(width: w,
                        height: h,
                        bitsPerComponent: 8,
                        bitsPerPixel: 32,
                        bytesPerRow: 4 * w,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: [
                          .byteOrder32Little,
                          CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                        ],
                        provider: CGDataProvider(data: data!)!,
                        decode: nil,
                        shouldInterpolate: false,
                        intent: .defaultIntent)

      // Save the image as an attachment.
      let s = XCTAttachment(image: UIImage(cgImage: img!))
      s.lifetime = XCTAttachment.Lifetime.keepAlways
      s.name = element.label // The label is the font name.
      add(s)
    }
  }
}
